class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: true, queue: :default

  def perform product_id
    Suggestion.new(product_id).build
  end

end