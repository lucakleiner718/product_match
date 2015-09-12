class ProductSuggestion < ActiveRecord::Base

  belongs_to :product
  belongs_to :suggested, class_name: 'Product', foreign_key: :suggested_id

  def self.fill brand: nil
    exitsts_ids = ProductSuggestion.select('distinct(product_id)').to_a.map(&:product_id)
    products = Product.where(brand: ['Current/Elliott', 'Eberjey', 'Joie', 'Honeydew Intimates']).where.not(id: exitsts_ids).where(source: :shopbop).where('upc is NULL')
    products = products.where(brand: brand) if brand
    products.find_each do |product|
      related_products = Product.where.not(source: :shopbop).where(brand: product.brand)

      title_parts = product.title.split(/\s/).map(&:downcase) - ['the']
      special_category = ['shorts', 'skirt', 'dress', 'jeans', 'pants', 'panties'] & title_parts
      if special_category.size > 0
        special_category.each do |category|
          related_products = related_products.where("title ILIKE :word or category ILIKE :word", word: "%#{category}%")
        end
      else
        related_products = related_products.where(title_parts.map{|el| "title iLIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))
      end

      related_products.each do |suggested|
        percentage = product.similarity_to suggested
        ProductSuggestion.create product: product, suggested: suggested, percentage: percentage if percentage > 0
      end
    end
  end

end
