class BrandStat

  def self.cached brand_id
    Rails.cache.fetch "brand/#{brand_id}/data", expires_in: 1.day do
      BrandStat.get(brand_id)
    end
  end

  def self.write brand_id
    Rails.cache.write "brand/#{brand_id}/data", BrandStat.get(brand_id)
  end

  def self.get brand
    brand = Brand.find(brand) if brand.is_a?(Integer) || brand.is_a?(String)

    shopbop_matched_size = ProductSelect.connection.execute("
      SELECT count(product_id) as amount
      FROM product_selects AS ps
      LEFT JOIN products AS pr ON pr.id=ps.product_id
      WHERE ps.decision='found' AND pr.brand IN (#{brand.names.map{|el| Product.sanitize el}.join(',')})
    ").to_a.first['amount'].to_i

    # binding.pry

    # shopbop_matched_size
    amounts = Product.amount_by_brand_and_source(brand.names)
    {
      name: brand.name,
      shopbop_size: Product.where(brand: brand.names).shopbop.size,
      shopbop_noupc_size: Product.where(brand: brand.names).shopbop.where("upc is null OR upc = ''").size,
      shopbop_matched_size: shopbop_matched_size,
      amounts_content: amounts.to_a.map{|el| el.join(': ')}.join('<br>'),
      amounts_values: amounts.values.sum,
      suggestions: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand: brand.names}).pluck(:product_id).uniq.size
    }
  end

end