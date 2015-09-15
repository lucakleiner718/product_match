class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options queue: :low, unqiue: true

  def perform product_id
    product = Product.find(product_id)
    related_products = Product.where.not(source: :shopbop).where(brand: Brand.get_by_name(product.brand).names)

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

  def self.spawn brand: nil, delete_exists: false
    if delete_exists && brand
      ProductSuggestion.where(product_id: Product.shopbop.where(brand: brand).pluck(:id)).delete_all
      exists_ids = []
    else
      exists_ids = ProductSuggestion.select('distinct(product_id)').to_a.map(&:product_id)
    end

    products = Product.where.not(id: exists_ids).where(source: :shopbop).where(upc: nil)
    if brand
      products = products.where(brand: Brand.find_by_name(brand).names)
    else
      products = products.where(brand: Brand.names_in_use)
    end
    products.find_each do |product|
      self.perform_async product.id
    end
  end
end