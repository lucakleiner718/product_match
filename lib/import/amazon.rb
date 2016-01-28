module Import
  class Amazon < Import::Base
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

      perform(sort: :price)
      return log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

      perform(sort: '-price')
      return log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

      perform(sort: :reviewrank)
      return log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

      perform(sort: :relevancerank)
      return log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

      categories = YAML.load_file('config/products_kinds.yml').values.flatten
      words = []
      Product.where(brand_id: brand.id).where(source: source).pluck(:title).each do |title|
        categories.each do |category|
          if title =~ /^#{Regexp.quote category}\s/i || title =~ /\s#{Regexp.quote category}$/i || title =~ /\s#{Regexp.quote category}\s/i
            words << category
          end
        end
      end

      words = words.uniq.compact

      words.each do |term|
        perform(term: term, sort: :price)
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: '-price')
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: :reviewrank)
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: :relevancerank)
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?
      end

      return log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

      words2 = []
      Product.where(brand_id: brand.id).where(source: source).pluck(:title).each do |title|
        categories.each do |category|
          if title =~ /^#{Regexp.quote category}\s/i || title =~ /\s#{Regexp.quote category}$/i || title =~ /\s#{Regexp.quote category}\s/i
            words2 << category
          end
        end
      end

      words2 = words2.uniq.compact - words
      words2.each do |term|
        results = perform(term: term, sort: :price)
        next if results < 90
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: '-price')
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: :reviewrank)
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?

        perform(term: term, sort: :relevancerank)
        break log("reached max #{processed_items.uniq.size}/#{total_amount}") if reached_max?
      end
    end

    def perform(params={})
      results = []
      params[:brand] = brand.name

      pageno = 1
      while true
        params[:item_page] = pageno
        res = send_request(params)
        break if res.items.size == 0
        # log("#{pageno}: #{res.items.size}")
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
      results.size
    end

    private

    attr_reader :brand, :processed_items, :total_amount

    def parse_item(item)
      title = item.get('ItemAttributes/Title')
      upc = item.get('ItemAttributes/UPC')
      ean = item.get('ItemAttributes/EAN')
      url = item.get('DetailPageURL').sub(/%3FSubscriptionId.*$/, '')
      image = item.get('LargeImage/URL')
      category = item.get('ItemAttributes/Binding')
      # response_brand = item.get('ItemAttributes/Brand')
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

      return unless gtin

      {
        title: title,
        upc: gtin,
        brand: brand.name,
        category: category,
        price: price.to_i / 100.0,
        price_currency: price_currency,
        color: color,
        size: size,
        url: url,
        image: image,
        source_id: source_id,
        style_code: style_code
      }
    end

    def send_request(params, attempt=0)
      sleep(0.5) if attempt == 0 # reduce amount of requests to amazon
      begin
        params = {
          response_group: :Large,
          search_index: :FashionWomen,
          sort: :price,
        }.merge(params)
        log params
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
            search_index: :FashionWomen, sort: :price,
            timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}))
    end

    def get_total_products_amount
      params = { brand: brand.name }
      res = send_request(params)
      @total_amount = res.get_element('Items TotalResults').get.to_i
    end

    def reached_max?
      total_amount <= processed_items.uniq.compact.size
    end
  end
end