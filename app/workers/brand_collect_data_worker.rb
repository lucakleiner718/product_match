class BrandCollectDataWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_executed

  def perform product_source_id
    product_source = ProductSource.find(product_source_id)

    case product_source.source_name
      when 'popshops'
        Import::Popshops.perform brand_id: product_source.source_id
      when 'linksynergy'
        Import::Linksynergy.perform mid: product_source.source_id, daily: true, last_update: product_source.collected_at
      when 'shopbop'
        Import::Shopbop.perform url: product_source.source_id, update_file: true
      when 'website'
        begin
          Module.const_get("Import::#{product_source.source_id.titleize}").perform
        rescue => e
          Rails.logger.info "Wrong import file name"
        end
      else
    end

    product_source.update_column :collected_at, Time.now
  end

  def self.spawn
    ProductSource.where('period > 0').where("collected_at < now() + INTERVAL '1 day' * period OR collected_at is null").limit(50).each do |ps|
      self.perform_async ps.id
    end
  end

end