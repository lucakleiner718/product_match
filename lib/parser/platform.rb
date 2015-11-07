class Parser::Platform

  def self.detect url
    resp = Curl::Easy.perform(url) do |curl|
      curl.headers["User-Agent"] = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
      # curl.verbose = true
      curl.follow_location = true
      curl.max_redirects = 10
      curl.timeout = 7
    end

    platform =
      if resp.response_code == 200
        if resp.body =~ /demandware\.static/
          :demandware
        elsif resp.body =~ /myshopify\.com/
          :shopify
        elsif resp.body =~ /\/skin\/frontend\//
          :magento
        elsif resp.body =~ /assets\.tumblr\.com/
          :tumblr
        elsif resp.body =~ /yoox\.biz/
          :yoox
        elsif resp.body =~ /bigcartel\.com/ || url =~ /\/\/[^\.]+\.bigcartel\.com/
          :bigcartel
        elsif resp.body =~ /static\.squarespace\.com/
          :squarespace
        elsif resp.body =~ /UniteU Commerce platform/
          :uniteu
        elsif resp.body =~ /bigcommerce\.com/
          :bigcommerce
        elsif resp.body =~ /weebly\.com/
          :weebly
        elsif resp.body =~ /Venda\./
          :venda
        elsif resp.body =~ /\/front\/app\/subscription\// && resp.body =~ /\/front\/app\/account\/home/
          :unknown01
        elsif resp.body =~ /3dcart\.com/
          '3dcart'
        elsif resp.body =~ /App_Themes/
          :asp_net
        elsif resp.body =~ /Onestop\.Commerce/
          :onestop
        elsif resp.body =~ /content\=\"Orchard\"/
          :orchard
        elsif resp.body =~ /CatalystScript/ && resp.body =~ /CatalystStyles/
          :catalyst
        elsif resp.body =~ /WooCommerce/i
          :woocommerce
        elsif resp.body =~ /wp\-content/
          :wordpress
        elsif resp.body =~ /spree\/frontend/
          :spree
        elsif resp.body =~ /\/assets\/application-[a-z0-9]+\.js/
          :rails_app
        elsif resp.body =~ /static\.e\-merchant\.com/
          :emerchant
        elsif resp.body =~ /\/sites\/all\themes/ || resp.body =~ /content\=\"Drupal/
          :drupal
        end
      end

    [platform, resp.last_effective_url]
  rescue Curl::Err::HostResolutionError, Curl::Err::SSLPeerCertificateError,
    Curl::Err::TooManyRedirectsError, Curl::Err::RecvError, Curl::Err::TimeoutError,
    Curl::Err::SSLConnectError=> e
    [nil, nil]
  end

  def self.detect_multiple urls
    urls.map do |url|
      platform = self.detect(url)
      Rails.logger.debug "#{url} :: #{platform}"
      [url, platform]
    end
  end

  def self.process force: false
    data = CSV.read('tmp/sources/urls.csv')

    data.each_with_index do |row, index|
      url = row[0]
      used_url = row[1]
      platform = row[2]

      if url.downcase == '#N/A'.downcase || url == '0'
        next
      end

      if platform.blank? || (force && platform == 'n/a')
        begin
          platform, used_url = Parser::Platform.detect url
        rescue => e
        end
        platform ||= 'n/a'
      end

      data[index] = [url, used_url, platform]
      puts data[index].join(', ')

      csv_string = CSV.generate do |csv|
        data.each do |row|
          csv << row
        end
      end
      File.write 'tmp/sources/urls.csv', csv_string
    end
  end

end