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
          true
        when 'linksynergy'
          Import::Linksynergy.perform mid: product_source.source_id, daily: true,
            product_source: product_source
          true
        when 'shopbop'
          Import::Shopbop.perform url: product_source.source_id, update_file: true
          Product.where(source: :shopbop).where('created_at > ?', 12.hours.ago).pluck(:id).each do |pid|
            ProductSuggestionsWorker.perform_async pid
          end
          BrandStatWorker.spawn
          DailyStatWorker.perform_async
          ExportShopbopWorker.perform_async 'current'
          true
        when 'eastdane'
          Import::Eastdane.perform url: product_source.source_id, update_file: true
          Product.where(source: :eastdane).where('created_at > ?', 12.hours.ago).pluck(:id).each do |pid|
            ProductSuggestionsWorker.perform_async pid
          end
          BrandStatWorker.spawn
          DailyStatWorker.perform_async
          ExportShopbopWorker.perform_async 'current'
          true
        when 'website'
          const = product_source.source_id.titleize
          begin
            Module.const_get("Import::#{const}").perform

            true
          rescue NameError => e
            if e.message =~ /wrong constant name/
              Rails.logger.info "Wrong import file name"
              false
            else
              raise e
            end
          end
        else
          false
      end

    if response
      product_source.update_column :collected_at, Time.now if response
      if product_source.brand.try(:id)
        ProductSuggestionsWorker.perform_async product_source.brand_id
      end
    end
  end

  def self.spawn
    ProductSource.where('period > 0')
      .where("collected_at < now() - INTERVAL '1 day' * (period / #{1.day.to_i}) OR collected_at IS NULL")
      .order('collected_at ASC NULLS FIRST')
      .limit(50).each do |ps|

      self.perform_async ps.id
    end
  end

end