class BrandCollectDataWorker

  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform product_source_id
    product_source = ProductSource.find(product_source_id)

    if product_source.source_name == 'popshops'
      Import::Popshops.perform brand_id: product_source.source_id
      product_source.update_column :collected_at, Time.now
    elsif product_source.source_name == 'linksynergy'
      Import::Linksynergy.perform mid: product_source.source_id
      product_source.update_column :collected_at, Time.now
    end
  end

end