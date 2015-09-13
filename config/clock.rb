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

  every(1.day, 'ProductSuggestionsWorker', at: "00:00") { ProductSuggestionsWorker.spawn }

end