class CheckWebsiteWorker
  include Sidekiq::Worker

  def perform website_id, force: false
    website = Website.find(website_id)
    return if website.platform.present? && website.platform != 'n/a' && !force

    platform, url = Parser::Platform.detect(website.url || website.provided_url)
    website.platform = platform || 'n/a'
    website.url = url || 'n/a'
    website.save
  end

  def self.spawn file, force: false
    data = CSV.read(file).map(&:first)
    websites = Website.where(provided_url: data).group_by(&:provided_url)
    data.each do |url|
      website = websites[url].first
      website = Website.new unless website
      next if website.platform.present? && website.platform != 'n/a' && !force

      website.provided_url = url
      website.save if website.changed?

      CheckWebsiteWorker.perform_async website.id, force: force
    end
  end
end