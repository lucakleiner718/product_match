class BrandStatWorker

  include Sidekiq::Worker

  def perform brand_id
    BrandStat.write brand_id
  end

  def self.spawn
    Brand.in_use.each do |brand|
      self.perform_async brand.id
    end
  end

end