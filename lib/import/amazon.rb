module Import
  class Amazon < Import::Base
    class ReachedMax < StandardError; end

    SORT = [:price, :'-price', :'launch-date', :'popularity-rank', :relevancerank, :reviewrank]
    SEARCH_INDEX = :Fashion

    def source; 'amazon_ad_api'; end

    def self.perform(brand_name)
      self.new(brand_name).collect_data
    end

    def initialize(brand_name)
      @brand = Brand.where(name: brand_name).first_or_create
      @processed_items = []
    end

    def collect_data
      get_total_products_amount

      return if total_amount == 0

      collect_by_term

      words = get_keywords
      words.each do |term|
        collect_by_term(term)
      end

      words2 = get_keywords - words
      words2.each do |term|
        collect_by_term(term)
      end

      words3 = get_popular_words - words2 - words
      words3 = words3[0..30]
      words3.each do |term|
        collect_by_term(term)
      end

      log("Processed #{processed_items.uniq.size}/#{total_amount}")
    rescue ReachedMax => e
      log("reached max #{processed_items.uniq.size}/#{total_amount}")
      return
    end

    def perform(params={})
      results = []
      params[:brand] = brand.name

      pageno = 1
      while true
        params[:item_page] = pageno
        res = send_request(params)
        break if res.items.size == 0
        res.items.each do |item|
          processed_items << item.get('ASIN')

          row = parse_item(item)
          results << row if row
        end

        pageno += 1
        break if pageno > 10 || res.items.size < 10
      end

      prepare_items(results)
      process_results_batch(results)

      raise ReachedMax if reached_max?

      results.size
    end

    private

    attr_reader :brand, :processed_items, :total_amount

    def collect_by_term(term=nil)
      SORT.each do |sort|
        perform(term: term, sort: sort)
      end
    end

    def parse_item(item)
      title = item.get('ItemAttributes/Title')
      upc = item.get('ItemAttributes/UPC')
      ean = item.get('ItemAttributes/EAN')
      url = item.get('DetailPageURL').sub(/%3FSubscriptionId.*$/, '').sub(/%3Fpsc.*$/, '')

      images = [item.get('LargeImage/URL')]
      item.elem.css('ImageSets ImageSet LargeImage URL').each do |url|
        images << url.text
      end
      images.uniq!
      main_image = images.shift

      category = item.get('ItemAttributes/Binding')
      brand_name = item.get('ItemAttributes/Brand')
      color = item.get('ItemAttributes/Color')
      price = item.get('ItemAttributes/ListPrice/Amount')
      price_currency = item.get('ItemAttributes/ListPrice/CurrencyCode')
      unless price
        price = item.get('OfferSummary/LowestNewPrice/Amount')
        price_currency = item.get('OfferSummary/LowestNewPrice/CurrencyCode')
      end
      size = item.get('ItemAttributes/Size')
      source_id = item.get('ASIN')
      style_code = item.get('ParentASIN') || source_id

      # remove color and size from title
      title.sub!(/,\s#{Regexp.quote size}$/, '') if size
      title.sub!(/,\s#{Regexp.quote color}$/, '') if color
      title.sub!(/\s\(#{Regexp.quote size}, #{Regexp.quote color}\)/, '') if size && color

      gtin = upc || ean

      department = item.get('ItemAttributes/Department').to_s.downcase

      gender = nil
      gender = 'Female' if department.in? ['womens', 'girls']
      gender = 'Male' if department.in? ['mens', 'boys']

      return unless gtin

      {
        title: title,
        upc: gtin,
        brand: brand_name,
        category: category,
        price: price.to_i / 100.0,
        price_currency: price_currency,
        color: color,
        size: size,
        url: url,
        image: main_image,
        additional_images: images,
        source_id: source_id,
        style_code: style_code,
        gender: gender
      }
    end

    def send_request(params, attempt=0)
      sleep(0.5) if attempt == 0 # reduce amount of requests to amazon
      begin
        params = {
          response_group: :Large,
          search_index: SEARCH_INDEX,
          sort: :price,
        }.merge(params).merge(random_options)
        # log params
        term = params.delete(:term)
        ::Amazon::Ecs.item_search(term, params)
      rescue ::Amazon::RequestError => e
        raise e if attempt > 5
        sleep((attempt+1) * 3)
        log "Amazon::RequestError / attempt #{attempt}"
        send_request(params, attempt+1)
      end
    end

    def self.source_url(brand_name)
      ::Amazon::Ecs.send(:prepare_url, ::Amazon::Ecs.options.merge({
            brand: brand_name,
            operation: :ItemSearch, response_group: :Large,
            search_index: SEARCH_INDEX, sort: :price,
            timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}))
    end

    def get_total_products_amount
      params = { brand: brand.name }
      res = send_request(params)
      @total_amount = res.get_element('Items TotalResults').get.to_i
    end

    def reached_max?
      log "========= #{total_amount} / #{processed_items.uniq.compact.size} ========="
      # total_amount <= processed_items.uniq.compact.size
      false
    end

    def random_options
      keys = ENV['AMAZON_IMPORT_KEY'].split(',')
      secrets = ENV['AMAZON_IMPORT_SECRET'].split(',')
      tags = ENV['AMAZON_IMPORT_TAG'].split(',')
      index = rand(keys.size)

      {
        AWS_access_key_id: keys[index],
        AWS_secret_key: secrets[index],
        associate_tag: tags[index]
      }
    end

    def products_kinds
      @products_kinds ||= YAML.load_file('config/products_kinds.yml').values.flatten
    end

    def get_popular_words
      brand_products_titles.map{|title| title.downcase.gsub('-', '').gsub(/[^a-z0-9]/, ' ').split(' ')}.flatten.select{|item| item.size > 2}.each_with_object(Hash.new(0)) {|e, obj| obj[e] += 1}.sort_by{|(k,v)| -v}.map(&:first)
    end

    def get_keywords
      words = []
      brand_products_titles.each do |title|
        products_kinds.each do |category|
          if title =~ /^#{Regexp.quote category}\s/i || title =~ /\s#{Regexp.quote category}$/i || title =~ /\s#{Regexp.quote category}\s/i
            words << category
          end
        end
      end

      words.uniq.compact
    end

    def brand_products_titles
      Product.where(brand_id: brand.id).where(source: source).pluck(:title)
    end
  end
end