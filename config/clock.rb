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

  every(1.week, 'ExportShopbopWorkerLastWeek', at: "Monday 00:30") { ExportShopbopWorker.perform_async('last') }
  every(1.day, 'ExportShopbopWorkerCurrentWeek', at: "00:40") { ExportShopbopWorker.perform_async('current') }
  every(1.day, 'BrandStatWorker', at: "01:00") { BrandStatWorker.spawn }
  every(1.day, 'DailyStatWorker', at: "23:50") { DailyStatWorker.perform_async }
  every(1.hour, 'BrandCollectDataWorker') { BrandCollectDataWorker.spawn }
  every(1.day, 'RegenerateSuggestions', at: '03:00') do
    Brand.in_use.pluck(:id).each do |brand_id|
      ProductSuggestionsGeneratorWorker.perform_async(brand_id)
    end
  end

end