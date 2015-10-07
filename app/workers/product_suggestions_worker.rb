class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options queue: :default, unqiue: true

  def perform product_id
    Suggestion.build product_id
  end

end