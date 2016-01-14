class Import::Base

  def brand_name_default
    
  end

  def normalize_brand(brand_name)
    replacements = ['Michele', 'Current/Elliott', 'Alice + Olivia']
    replacements.each do |replacement|
      brand_name = replacement if brand_name.to_s.downcase == replacement.downcase
    end
    brand_name
  end

  def normalize_title(item)
    if item[:title].present?
      item[:title] = item[:title].encode("UTF-8", invalid: :replace, replace: '')
                       .to_s.sub(/#{Regexp.quote item[:brand].to_s}\s?/i, '')
                       .sub(/^(,|-)*/, '').strip.gsub('&#39;', '\'').gsub('&amp;', '&')
    end
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

  def prepare_items(items, check_upc_rule: false)
    items.map do |item|
      strip_data(item)
      normalize_title(item)
      normalize_color(item)
      prepare_prices(item)
      prepare_additional_images(item)
      check_upc(item, check_upc_rule)
      process_gender(item)
      check_source(item)
    end
    convert_brand(items)
  end

  def strip_data(item)
    item.each do |k, v|
      item[k] = v.strip if v.is_a?(String)
    end
  end

  def check_source(item)
    item[:source] = source if item[:source].blank? && source
  end

  def process_gender(item)
    item[:gender] = process_title_for_gender(item[:title]) if item[:gender].blank?
    item[:gender] = process_category_for_gender(item[:category]) if item[:gender].blank?
  end

  def prepare_prices(item)
    if item[:price_sale].present? && item[:price_sale] == item[:price]
      item[:price_sale] = nil
    end

    item[:price_currency] ||= nil

    if item[:price] =~ /^\$/
      item[:price].sub!(/^\$/, '')
      item[:price_currency] = "USD"
    end
  end

  def check_upc(item, check_upc_rule)
    if item[:ean].present? && item[:upc].blank?
      item[:upc] = item[:ean]
    end

    item.delete :ean
    item[:upc] = nil if item[:upc].blank? || item[:upc] !~ /\A\d+\z/
    if check_upc_rule && item[:upc].present?
      item[:upc] = (GTIN.process(item[:upc]) || nil)
    end
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
    brands_names << brand_name_default if brands_names.size == 0 && brand_name_default

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

  def build_url(url)
    url.sub!(/^\/\//, 'http://')
    url = "#{baseurl}#{'/' if url[0] != '/'}#{url}" if url[0,4] != 'http'
    url
  end

  def get_request(url, params={})
    url = build_url(url)
    send_typhoeus_get(url, params)
  end

  def process_title_for_gender(title)
    if title.downcase =~ /^women's\s/
      'Female'
    elsif title.downcase =~ /^men's\s/
      'Male'
    end
  end

  def process_category_for_gender(category)
    return unless category
    if category.downcase =~ /\swomen('s)?\s/ || category.downcase =~ /\swomen('s)?$/ || category.downcase =~ /^women('s)?\s/
      'Female'
    elsif category.downcase =~ /\smen('s)?\s/ || category.downcase =~ /\smen('s)?$/ || category.downcase =~ /^men('s)?\s/
      'Male'
    end
  end

  def log str
    Rails.logger.debug str
  end

  def process_products_urls urls
    urls.compact.map{|url| build_url(url).sub(/\?.*/, '')}.uniq
  end

  def self.perform(*args)
    self.new(*args).perform
  end

  def self.process_product(url, *args)
    self.new.process_product(url, *args)
  end

  def self.process_category(url, *args)
    self.new.process_category(url, *args)
  end

  def perform

  end

  def spawn_products_urls(urls, process_urls=true)
    urls = process_products_urls(urls) if process_urls
    if Rails.env.production?
      process_in_batch(urls)
    else
      urls.each{|url| spawn_url('product', url)}
    end
    log "spawned #{urls.size} urls"
  end

  def init_js(vars: [], funcs: [])
    new_rows = []
    new_rows << "var #{vars.join(',')};" if vars.size > 0
    funcs.each do |func|
      new_rows << "function #{func}(){};"
    end
    new_rows.join
  end

  def process_results_batch(results)
    to_update = []
    to_create = []

    if results.size == results.select{|r| r[:source_id].present?}.size
      products = Product.where(source: source, source_id: results.map{|r| r[:source_id]})
                   .group_by{|pr| pr.source_id}
      results.each do |r|
        exists = products[r[:source_id]].try(:first)
        if exists
          to_update << [r, exists]
        else
          to_create << r
        end
      end
    elsif results.size == results.select{|r| r[:style_code].present?}.size
      products = Product.where(source: source, style_code: results.map{|r| r[:style_code]}.uniq).to_a
      results.each do |r|
        exists = products.find{|pr| r[:style_code] == pr.style_code && r[:color] == pr.color && r[:size] == pr.size}
        if exists
          to_update << [r, exists]
        else
          to_create << r
        end
      end
    elsif results.size == results.select{|r| r[:upc].present?}.size
      products = Product.where(source: source, upc: results.map{|r| r[:upc]}.uniq)
                   .group_by{|pr| pr.upc}
      results.each do |r|
        exists = products[r[:upc]].try(:first)
        if exists
          to_update << [r, exists]
        else
          to_create << r
        end
      end
    else
      raise Exception, 'No options to process results'
    end

    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:created_at, :updated_at]
      tn = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([tn, tn]).map{|el| Product.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}
                RETURNING id"
      Product.connection.execute sql
    end

    to_update.each do |row|
      product, exist = row

      product.delete :upc if product[:upc].blank?
      exist.attributes = product
      exist.save! if exist.changed?
    end
  end

  def url_mtime(url)
    Net::HTTP.start(URI(url).host) do |http|
      resp = http.head(url)
      Time.parse(resp['last-modified'])
    end
  end

  private

  def send_typhoeus_get(url, params={})
    Typhoeus.get(url,
      followlocation: true,
      # verbose: true,
      maxredirs: 10,
      params: params,
      timeout: 30,
      connecttimeout: 30
    )
  end

  def process_in_batch(urls)
    batch.jobs do
      urls.each do |url|
        spawn_url('product', url)
      end
    end
  end

  def batch
    unless @batch
      @batch = Sidekiq::Batch.new
      @batch.description = "#{self.class.name}"
    end
    @batch
  end

  def spawn_url(kind, url, *args)
    if Rails.env.production?
      ProcessImportUrlWorker.perform_async(self.class.name, "process_#{kind}", url, *args)
    else
      ProcessImportUrlWorker.new.perform(self.class.name, "process_#{kind}", url, *args)
    end
  end
end
