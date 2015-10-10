class MigrateProductsBrandWorker

  include Sidekiq::Worker

  def perform brand_name
    products = Product.where(brand_id: nil).where(brand: brand_name)
    brand = Brand.get_by_name(brand_name)
    brand = Brand.create(name: brand_name) unless brand
    products.update_all(brand_id: brand.id)
  end

  def self.spawn
    brands_names = Product.select('distinct(brand)').map{|pr| pr.brand}.sort
    brands_names.each { |bn| MigrateProductsBrandWorker.perform_async bn }
  end

end