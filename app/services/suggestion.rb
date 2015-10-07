class Suggestion

  def self.build product_id
    product = Product.find(product_id)
    brand = Brand.get_by_name(product.brand) || Brand.create(name: product.brand)
    related_products = Product.not_shopbop.where(brand: brand.names).with_upc

    title_parts = product.title.gsub(/[,\.\-\(\)\'\"]/, '').split(/\s/).map{|el| el.downcase.strip}
                    .select{|el| el.size > 2} - ['the', '&', 'and', 'womens']
    # special_category = Product::CLOTH_KIND & title_parts
    # if special_category.size > 0
    #   special_category.each do |category|
    #     related_products = related_products.where("title ILIKE :word or category ILIKE :word", word: "%#{category}%")
    #   end
    # else
      related_products = related_products.where(title_parts.map{|el| "title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))
    # end

    exists = ProductSuggestion.where(product_id: product.id, suggested_id: related_products.map(&:id)).inject({}){|obj, el| obj["#{el.product_id}_#{el.suggested_id}"] = el; obj}
    to_create = []

    related_products.find_each do |suggested|
      percentage = product.similarity_to suggested
      ps = exists["#{product.id}_#{suggested.id}"]
      if percentage && percentage > 30
        if ps
          ps.percentage = percentage
          ps.save if ps.changed?
        else
          to_create << {product_id: product.id, suggested_id: suggested.id, percentage: percentage, created_at: Time.now, updated_at: Time.now}
        end
      end
    end

    if to_create.size > 0
      begin
        ProductSuggestion.connection.execute("INSERT INTO product_suggestions (product_id, suggested_id, percentage, created_at, updated_at) VALUES
          #{to_create.map{|r| "(#{r.values.map{|el| ProductSuggestion.sanitize el}.join(',')})"}.join(',')}
          ")
      rescue ActiveRecord::RecordNotUnique => e
        to_create.each do |row|
          row.delete :created_at
          row.delete :updated_at
          ProductSuggestion.create row rescue nil
        end
      end
    end

    to_create.size

    # delete not needed suggestions if we have some popular
    # if ProductSuggestion.where(product_id: product.id).where('percentage > 50').size > 0
    #   ProductSuggestion.where(product_id: product.id).where('percentage <= 40').delete_all
    # end
  end

end