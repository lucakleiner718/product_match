class Import::Base

  def normalize_brand brand_name
    replacements = ['Michele', 'Current/Elliott', 'Alice + Olivia']
    replacements.each do |replacement|
      brand_name = replacement if brand_name.to_s.downcase == replacement.downcase
    end
    brand_name
  end

  def normalize_title title, brand
    title.sub(/#{Regexp.quote brand.to_s}\s?/i, '').sub(/^(,|-)*/, '').strip.gsub('&#39;', '\'')
  end

  def normalize_retailer retailer
    retailer
  end

  def baseurl
    nil
  end

  def source
    if baseurl
      URI(baseurl).host.sub(/^www\./,'')
    else
      self.class.name.match(/\:\:(.*)/)[1].downcase
    end
  end

  def csv_chunk_size
    1_000
  end

  def convert_brand items
    brands_names = items.map{|it| it[:brand].to_s}.uniq.select{|it| it.present?}
    exists_brands = Brand.where("name IN (?) OR synonyms && ?", brands_names, "{#{brands_names.map{|e| e}.join(',')}}")
    brands = brands_names.map do |brand_name|
      brand = exists_brands.select{|b| b.name == brand_name || brand_name.in?(b.synonyms)}.first
      begin
      brand = Brand.create(name: brand_name) unless brand
      rescue ActiveRecord::RecordNotUnique => e
        brand = Brand.get_by_name(brand_name)
      end
      brand
    end
    items.map do |item|
      br = brands.select{|b| b.name == item[:brand] || item[:brand].in?(b.synonyms) }.first
      item[:brand_id] = br.try(:id)
      item.delete :brand
    end
    items
  end

  def build_url url
    url = "#{baseurl}#{'/' if url !~ /^\//}#{url}" if url !~ /^http/
    url
  end

  def get_request url
    url = build_url(url)

    retries = 0
    begin
      Curl.get(url) do |http|
        http.enable_cookies = true
        http.follow_location = true
        http.max_redirects = 10
        http.useragent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36'
        # http.verbose = true
      end
    rescue Curl::Err::PartialFileError => e
      retries += 1
      retry if retries < 6
      raise e
    end
  end

  def process_title_for_gender product_name
    if product_name.downcase =~ /^women's\s/
      'Female'
    elsif product_name.downcase =~ /^men's\s/
      'Male'
    end
  end

  def self.process_url url
    self.new.process_url url
  end

  def log str
    Rails.logger.debug str
  end

  def process_products_urls urls
    urls.map{|url| build_url(url).sub(/\?.*/, '')}.uniq
  end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    urls = get_products_urls
    spawn_products_urls urls
  end

  def get_products_urls
    []
  end

  def spawn_products_urls urls
    urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
    log "spawned #{urls.size} urls"
  end

end