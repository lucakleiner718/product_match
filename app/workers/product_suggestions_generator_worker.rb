class ProductSuggestionsGeneratorWorker

  include Sidekiq::Worker
  sidekiq_options queue: :middle, unqiue: true

  def perform brand_id, *args
    brand_id = brand_id.to_i
    options = args.extract_options!
    options.symbolize_keys!

    brand = Brand.find(brand_id)

    exists_ids = ProductSuggestion.select('distinct(product_id)')
                 .joins("JOIN products on products.id=product_suggestions.product_id
                         AND products.source IN (#{Product::MATCHED_SOURCES.map{|e| Product.sanitize e}.join(',')})
                         AND products.brand_id=#{brand_id}").to_a.map(&:product_id)

    products = Product.where.not(id: exists_ids).matching.where(match: true).without_upc
    products = products.where(brand_id: brand.id)

    in_batch(brand) do
      products.find_each do |product|
        ProductSuggestionsWorker.perform_async product.id
      end
    end
    products.size
  end

  def self.spawn
    Brand.in_use.pluck(:id).each do |brand_id|
      self.perform_async brand_id
    end
  end

  private

  def in_batch(brand)
    batch = Sidekiq::Batch.new
    batch.description = "Product suggestions #{brand.name} (#{brand.id})"
    batch.on(:success, 'SidekiqCallback::ProductSuggestions', brand_id: brand.id)
    batch.jobs do
      yield
    end
  end

end