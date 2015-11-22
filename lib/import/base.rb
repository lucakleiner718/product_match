class Import::Base

  def normalize_brand brand_name
    replacements = ['Michele', 'Current/Elliott', 'Alice + Olivia']
    replacements.each do |replacement|
      brand_name = replacement if brand_name.to_s.downcase == replacement.downcase
    end
    brand_name
  end

  def normalize_title item
    if item[:title].present?
      item[:title] = item[:title].to_s.sub(/#{Regexp.quote item[:brand].to_s}\s?/i, '')
                       .sub(/^(,|-)*/, '').strip.gsub('&#39;', '\'')
    end
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

  def prepare_items items, check_upc_rule: :full
    items.map do |item|
      normalize_title(item)
      normalize_color(item)
      prepare_prices(item)
      prepare_additional_images(item)
      check_upc(item, check_upc_rule)
      process_gender(item)
    end
    convert_brand(items)
  end

  def process_gender(item)
    if item[:gender].blank?
      item[:gender] = process_title_for_gender(item[:title])
    end
  end

  def prepare_prices(item)
    if item[:price_sale].present? && item[:price_sale] == item[:price]
      item[:price_sale] = nil
    end
  end

  def check_upc(item, check_upc_rule=:full)
    if item[:ean].present?
      item[:upc] = item[:ean] if item[:upc].blank?
    end

    item.delete :ean
    # if check_upc_rule.to_sym == :full && item[:upc].present?
    #   item[:upc] = (GTIN.process(item[:upc]) || nil)
    # end
  end

  def prepare_additional_images item
    if item[:additional_images] && item[:additional_images].size > 0
      item[:additional_images] = item[:additional_images].select{|img| img.present?}
    end
  end

  def normalize_color item
    item[:color] = item[:color].to_s.gsub('&amp;', '&') if item[:color].present?
  end

  def convert_brand items
    brands_names = items.map{|it| it[:brand].to_s.sub(/\A"/, '').sub(/"\z/, '')}.uniq.select{|it| it.present?}
    exists_brands = Brand.where("name IN (?) OR synonyms && ?", brands_names, "{#{brands_names.map{|e| e.gsub('"', '\"').gsub('{', '\{').gsub('}', '\}')}.join(',')}}")
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
      item[:brand_name] = br.try(:name)
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
    rescue Curl::Err::PartialFileError, Curl::Err::HostResolutionError => e
      retries += 1
      retry if retries < 6
      raise e
    end
  end

  def process_title_for_gender title
    if title.downcase =~ /^women's\s/
      'Female'
    elsif title.downcase =~ /^men's\s/
      'Male'
    end
  end

  def self.process_url *args
    self.new.process_url *args
  end

  def log str
    Rails.logger.debug str
  end

  def process_products_urls urls
    urls.map{|url| build_url(url).sub(/\?.*/, '')}.uniq
  end

  def self.perform *args
    instance = self.new *args
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

  def process_results results, brand_name=nil
    brand = Brand.get_by_name(brand_name)
    if !brand && brand_name_default
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name if brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      next if (row[:upc].present? && row[:upc] !~ /\A\d{12,}\z/) ||
        row[:color].blank? || row[:size].blank?

      product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      if brand
        product.brand_id = brand.id
        product.brand_name = brand.name
      end
      product.save
    end
  end

end