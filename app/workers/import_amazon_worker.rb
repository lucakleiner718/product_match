class ImportAmazonWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, queue: :amazon_import

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
          Import::Amazon.perform(product_source.source_id)
          brand = product_source.brand
          brand = Brand.get_by_name(product_source.source_id) unless brand
          if brand
            Product.where(source: :shopbop).where(brand_id: brand.id).pluck(:id).each do |pid|
              ProductSuggestionsWorker.perform_async(pid)
            end
          end
          true
        else
          false
      end

    if response
      product_source.update_column :collected_at, Time.now if response
      if product_source.brand.try(:id)
        ProductSuggestionsGeneratorWorker.perform_async(product_source.brand_id)
      end
    end
  end
end
