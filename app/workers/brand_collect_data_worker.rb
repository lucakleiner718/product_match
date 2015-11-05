class BrandCollectDataWorker

  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform product_source_id
    begin
      product_source = ProductSource.find(product_source_id)
    rescue ActiveRecord::RecordNotUnique => e
      return false
    end

    response =
      case product_source.source_name
        when 'popshops'
          Import::Popshops.perform brand_id: product_source.source_id
        when 'linksynergy'
          Import::Linksynergy.perform mid: product_source.source_id, daily: true,
            product_source: product_source
        when 'shopbop'
          Import::Shopbop.perform url: product_source.source_id, update_file: true
        when 'website'
          begin
            Module.const_get("Import::#{product_source.source_id.titleize}").perform
            true
          rescue => e
            Rails.logger.info "Wrong import file name"
            false
          end
        else
          false
      end

    product_source.update_column :collected_at, Time.now if response
  end

  def self.spawn
    ProductSource.where('period > 0')
      .where("collected_at < now() - INTERVAL '1 day' * period OR collected_at IS NULL")
      .order('collected_at ASC NULLS FIRST')
      .limit(50).each do |ps|

      self.perform_async ps.id
    end
  end

end