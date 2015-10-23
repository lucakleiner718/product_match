class ProductSuggestionsGeneratorWorker

  include Sidekiq::Worker
  sidekiq_options queue: :middle, unqiue: true

  def perform brand_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    brand = Brand.find(brand_id)

    delete_exists = options[:delete_exists]

    if delete_exists && brand
      if (delete_exists.is_a?(String) || delete_exists.is_a?(Symbol)) && delete_exists.to_sym == :except_green
        bops_products = Product.shopbop.where(brand_id: brand.id, match: true).pluck(:id)
        exists_ids = ProductSuggestion.where(product_id: bops_products, percentage: 100).pluck(:product_id).uniq
        ProductSuggestion.where(product_id: bops_products - exists_ids).delete_all
      else
        ProductSuggestion.where(product_id: Product.shopbop.where(brand_id: brand.id).pluck(:id)).delete_all
        exists_ids = []
      end
    else
      exists_ids = ProductSuggestion.select('distinct(product_id)').to_a.map(&:product_id)
    end

    products = Product.where.not(id: exists_ids).where(source: :shopbop, match: true).where(upc: nil)
    products = products.where(brand_id: brand.id)
    products.find_each do |product|
      ProductSuggestionsWorker.perform_async product.id
    end
  end

  def self.spawn
    Brand.in_use.pluck(:id).each do |brand_id|
      self.perform_async brand_id
    end
  end

end