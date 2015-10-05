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

  every(1.day, 'ProductSuggestionsGeneratorWorker', at: "02:00") { ProductSuggestionsGeneratorWorker.perform_async }
  every(1.day, 'BrandStatWorker', at: "01:00") { BrandStatWorker.spawn }
  every(1.day, 'BrandCollectDataWorker', at: "00:00") { BrandCollectDataWorker.spawn }

end