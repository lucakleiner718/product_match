require 'clockwork'
require 'clockwork/database_events'
require_relative './boot'
require_relative './environment'

module Clockwork
  handler do |job, time|
    puts "Running #{job}, at #{time}"
  end

  configure do |config|
    config[:tz] = Time.zone
  end

  every(1.day, 'ExportShopbopWorker', at: "23:00") { ExportShopbopWorker.perform_async }
  every(1.day, 'ProductSuggestionsGeneratorWorker', at: "02:00") { ProductSuggestionsGeneratorWorker.spawn }
  every(1.day, 'BrandStatWorker', at: "01:00") { BrandStatWorker.spawn }
  every(1.hour, 'BrandCollectDataWorker') { BrandCollectDataWorker.spawn }

end