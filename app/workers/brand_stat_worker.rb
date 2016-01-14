class BrandStatWorker

  include Sidekiq::Worker
  # sidekiq_options unqiue: true, unique_args: ->(args) { [ args.first ] }

  def perform brand_id
    brand = Brand.find(brand_id)
    brand.update_stat
  end

  def self.spawn
    Brand.in_use.each do |brand|
      self.perform_async brand.id
    end
  end

end