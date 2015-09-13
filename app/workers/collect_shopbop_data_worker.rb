class CollectShopbopDataWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: true

  def perform
    Import::Shopbop.perform
  end
end