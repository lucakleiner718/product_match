class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: until_executed, queue: :default

  def perform product_id
    Suggestion.build product_id
  end

end