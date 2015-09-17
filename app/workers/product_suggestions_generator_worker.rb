class ProductSuggestionsGeneratorWorker

  include Sidekiq::Worker
  sidekiq_options queue: :middle

  def perform *args
    options = args.extract_options!
    options.symbolize_keys!
    brand = options[:brand]
    delete_exists = options[:delete_exists]
    
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
      ProductSuggestionsWorker.perform_async product.id
    end
  end

end