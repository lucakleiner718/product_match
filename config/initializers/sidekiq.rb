Sidekiq.default_worker_options = {
  backtrace: true,
  # retry: false
}

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], namespace: "retailers_sidekiq_#{Rails.env}" }
  # config.error_handlers << Proc.new { |ex, context| Airbrake.notify_or_ignore(ex, parameters: context) }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'], namespace: "retailers_sidekiq_#{Rails.env}" }
end

SidekiqUniqueJobs.config.unique_args_enabled = true

# Sidekiq Pro Reliability feature
Sidekiq::Client.reliable_push! unless Rails.env.test?
Sidekiq.configure_server do |config|
  config.reliable_fetch!
  config.reliable_scheduler!
end