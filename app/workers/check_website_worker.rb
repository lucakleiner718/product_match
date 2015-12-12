class CheckWebsiteWorker
  include Sidekiq::Worker

  def perform website_id, force=false
    website = Website.find(website_id)
    if website.platform.blank? || (website.platform == 'n/a' && force)
      request_url = website.provided_url
      request_url = website.url if website.url.present? && website.url != 'n/a'

      platform, url = Parser::Platform.detect(request_url)
      website.platform = platform || 'n/a'
      website.url = url || 'n/a'
      website.save! if website.changed?
    end
  end

  def self.spawn file, force=false
    data = CSV.read(file).map(&:first)
    websites = Website.where(provided_url: data).group_by(&:provided_url)
    data.each do |url|
      website = websites[url].first
      website = Website.new unless website
      if website.platform.blank? || (website.platform == 'n/a' && force)
        website.provided_url = url
        website.save! if website.changed?

        CheckWebsiteWorker.perform_async website.id, force
      end
    end
  end
end