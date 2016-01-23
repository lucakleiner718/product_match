class ProductSuggestionsGeneratorWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: true, queue: :middle

  def perform(brand_id, *args)
    brand_id = brand_id.to_i
    options = args.extract_options!
    options.symbolize_keys!

    brand = Brand.find(brand_id)
    products = Product.matching.where(in_store: true, match: true).without_upc.where(brand_id: brand.id)

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
