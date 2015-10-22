class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: true, queue: :default

  def perform product_id
    Suggestion.build product_id
  end

end