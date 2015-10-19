class PopulateProductUpcWorker

  include Sidekiq::Worker

  def perform product_select_id
    PopulateProductUpc.perform product_select_id
  end

  def self.spawn
    PopulateProductUpc.for_populate.each do |id|
      self.perform_async id
    end
  end
end