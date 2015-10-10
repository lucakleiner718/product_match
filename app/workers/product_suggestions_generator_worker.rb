class ProductSuggestionsGeneratorWorker

  include Sidekiq::Worker
  sidekiq_options queue: :middle

  def perform *args
    options = args.extract_options!
    options.symbolize_keys!

    brand = nil
    brand = Brand.find_by_name(options[:brand]) if options[:brand]
    brand = Brand.find(options[:brand_id]) if options[:brand_id]

    delete_exists = options[:delete_exists]

    if delete_exists && brand
      ProductSuggestion.where(product_id: Product.shopbop.where(brand_id: brand.id).pluck(:id)).delete_all
      exists_ids = []
    else
      exists_ids = ProductSuggestion.select('distinct(product_id)').to_a.map(&:product_id)
    end

    products = Product.where.not(id: exists_ids).where(source: :shopbop).where(upc: nil)
    if brand
      products = products.where(brand_id: brand.id)
    else
      products = products.where(brand_id: Brand.in_use.pluck(:id))
    end
    products.find_each do |product|
      ProductSuggestionsWorker.perform_async product.id
    end
  end

end