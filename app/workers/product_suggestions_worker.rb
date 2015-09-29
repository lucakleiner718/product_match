class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options queue: :default, unqiue: true

  def perform product_id
    product = Product.find(product_id)
    related_products = Product.where.not(source: :shopbop).where(brand: Brand.get_by_name(product.brand).names)

    title_parts = product.title.split(/\s/).map(&:downcase) - ['the']
    special_category = ['shorts', 'skirt', 'dress', 'jeans', 'pants', 'panties', 'bra'] & title_parts
    if special_category.size > 0
      special_category.each do |category|
        related_products = related_products.where("title ILIKE :word or category ILIKE :word", word: "%#{category}%")
      end
    else
      related_products = related_products.where(title_parts.map{|el| "title iLIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))
    end

    exists = ProductSuggestion.where(product_id: product.id, suggested_id: related_products.map(&:id))
    related_products.each do |suggested|
      percentage = product.similarity_to suggested
      ps = exists.select{|ps| ps.product_id == product.id && ps.suggested_id == suggested }.first
      ps = ProductSuggestion.new product: product, suggested: suggested unless ps
      percentage = 0 unless percentage
      ps.percentage = percentage
      ps.save if ps.changed?
    end
  end

end