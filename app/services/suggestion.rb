class Suggestion

  COLOR_WEIGHT = 5
  SIZE_WEIGHT = 2
  TITLE_WEIGHT = 5
  PRICE_WEIGHT = 2

  def self.build product_id
    instance = self.new
    instance.build_suggestions product_id
  end

  def build_suggestions product_id
    product = Product.find(product_id)
    brand_name = product.brand.try(:name)
    return false unless brand_name
    brand = Brand.get_by_name(brand_name) || Brand.create(name: brand_name)
    related_products = Product.not_shopbop.where(brand_id: brand.id).with_upc

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
      percentage = similarity_to product, suggested
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

  def similarity_to product, suggested
    params_amount = TITLE_WEIGHT + COLOR_WEIGHT + SIZE_WEIGHT + PRICE_WEIGHT
    params_count = []

    title_parts = product.title.split(/\s/).map{|el| el.downcase.gsub(/[^a-z]/i, '')}.select{|el| el.size > 2}
    title_parts -= ['the', '&', 'and', 'womens', 'women’s']
    suggested_title_parts = suggested.title.split(/\s/).map{|el| el.downcase.gsub(/[^a-z]/i, '')}
    title_similarity = (title_parts.size > 0 ? title_parts.select{|item| item.in?(suggested_title_parts)}.size / title_parts.size.to_f : 1) * TITLE_WEIGHT

    params_count << title_similarity
    # return 0 if title_similarity < 2

    if suggested.color.present? && product.color.present?
      if suggested.color.gsub(/\s/, '').downcase == product.color.gsub(/\s/, '').downcase
        params_count << COLOR_WEIGHT
      else
        color_s = suggested.color.gsub(/\s/, '').downcase.split(/[\/,]/)
        color_p = product.color.gsub(/\s/, '').downcase.split(/[\/,]/)

        if color_s.size == 2 && color_p.size == 1
          if color_s.first == color_p.first || color_s.last == color_p.first
            params_count << COLOR_WEIGHT
          end
        elsif color_s.size == 2 && color_p.size == 2
          if color_s.sort.join == color_p.sort.join
            params_count << COLOR_WEIGHT
          end
        end
      end
    end

    if suggested.size.present? && product.size.present?
      size_s = suggested.size.gsub(/\s/, '').downcase
      size_p = product.size.gsub(/\s/, '').downcase

      if size_s == size_p || (size_s == 'small' && size_p == 's') || (size_s == 'large' && size_p == 'l') ||
      (size_s == 'medium' && size_p == 'm') || (size_s == 'x-small' && size_p == 'xs') || (size_s == 'petite' && size_p == 'p')
        params_count << SIZE_WEIGHT
      elsif size_s =~ /us/ && size_s =~ /eu/
        eu_size = size_s.match(/(\d{1,2}\.?\d?)eu/i)
        if eu_size && size_p == eu_size[1]
          params_count << SIZE_WEIGHT
        end
      end
    else
      if suggested.size.blank? && product.size.present? && product.size.downcase == 'one size'
        params_count << SIZE_WEIGHT
      end
    end

    if suggested.price.present? && product.price.present?
      dif = (suggested.price.to_i - product.price.to_i).abs / product.price.to_f
      dif = 1 if dif > 1
      dif = 1 - dif

      params_count << (dif * PRICE_WEIGHT).round(2)
    end

    (params_count.sum/params_amount.to_f * 100).to_i
  end

end