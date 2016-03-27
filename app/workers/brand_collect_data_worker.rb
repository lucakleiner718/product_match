class BrandCollectDataWorker

  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform(product_source_id, force: false)
    begin
      product_source = ProductSource.find(product_source_id)
    rescue ActiveRecord::RecordNotFound
      return false
    end

    return if product_source.up_to_date? && !force

    response =
      case product_source.source_name
        when 'amazon_ad_api'
          ImportAmazonWorker.perform_async(product_source_id)
          false
        when 'cj'
          Import::Cj.perform(product_source_id)
          true
        when 'popshops'
          Import::Popshops.perform(brand: product_source.source_id)
          true
        when 'popshops_merchant'
          Import::Popshops.perform(merchant: product_source.source_id)
          true
        when 'linksynergy'
          Import::Linksynergy.perform(mid: product_source.source_id, daily: true,
            product_source: product_source)
          true
        when 'shopbop'
          resp = Import::Shopbop.perform product_source.source_id, force
          return false unless resp
          Product.where(source: :shopbop).where('created_at > ?', 12.hours.ago).pluck(:id).each do |pid|
            ProductSuggestionsWorker.perform_async pid
          end
          BrandStatWorker.spawn
          DailyStatWorker.perform_async
          ExportShopbopWorker.perform_async 'current'
          true
        when 'eastdane'
          resp = Import::Eastdane.perform product_source.source_id
          return false unless resp
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
      product_source.touch(:collected_at) if response
      if product_source.brand.try(:id)
        ProductSuggestionsGeneratorWorker.perform_async(product_source.brand_id)
      end
    end
  end

  def self.spawn
    ProductSource.outdated.order('collected_at ASC NULLS FIRST').each do |ps|
      self.perform_async(ps.id)
    end
  end
end
