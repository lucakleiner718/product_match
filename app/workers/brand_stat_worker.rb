class BrandStatWorker

  include Sidekiq::Worker

  def perform brand_id
    Rails.cache.write "brand/#{brand_id}/data", expires_in: 1.day do
      BrandStat.get(brand_id)
    end
  end

  def self.spawn
    Brand.in_use.each do |brand|
      self.perform_async brand.id
    end
  end

end