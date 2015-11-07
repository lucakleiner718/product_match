class CheckWebsiteWorker
  include Sidekiq::Worker

  def perform website_id
    website = Website.find(website_id)
    platform, url = Parser::Platform.detect(website.url || website.provided_url)
    website.platform = platform || 'n/a'
    website.url = url || 'n/a'
    website.save
  end

  def self.spawn file
    data = CSV.read(file)
    data.each do |row|
      website = Website.where('provided_url = :url OR url = :url', url: row[0]).first_or_initialize
      website.provided_url = row[0]
      website.save
      self.perform_async website.id
    end
  end
end