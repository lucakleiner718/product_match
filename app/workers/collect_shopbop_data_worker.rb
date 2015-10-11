class CollectShopbopDataWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: until_executed

  def perform
    Import::Shopbop.perform
  end
end