class SidekiqCallback::Import < SidekiqCallback::Base
  def on_success(status, options)
    BrandStatWorker.perform_async(options['brand_id'])
  end
end