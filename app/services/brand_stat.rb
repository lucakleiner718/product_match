class BrandStat

  def self.get brand
    brand = Brand.find(brand) if brand.is_a? Integer
    amounts = Product.amount_by_brand_and_source(brand.names)
    {
      name: brand.name,
      shopbop_size: Product.where(brand: brand.names).shopbop.size,
      shopbop_noupc_size: Product.where(brand: brand.names).shopbop.where("upc is null OR upc = ''").size,
      amounts_content: amounts.to_a.map{|el| el.join(': ')}.join('<br>'),
      amounts_values: amounts.values.sum,
      suggestions: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand: brand.names}).pluck(:product_id).uniq.size
    }
  end

end