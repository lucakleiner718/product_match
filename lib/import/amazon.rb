module Import
  class Amazon < Import::Base
    def source; 'amazon_ad_api'; end

    def self.perform(brand)
      inst = self.new
      inst.perform(brand, {sort: :price})
      inst.perform(brand, {sort: '-price'})
      inst.perform(brand, {sort: :reviewrank})
      inst.perform(brand, {sort: :relevancerank})
    end

    def perform(brand, params={})
      @brand = brand
      results = []
      params[:brand] = brand

      pageno = 1
      while true
        params[:item_page] = pageno
        res = send_request(params)
        break if res.items.size == 0
        # log("#{pageno}: #{res.items.size}")
        res.items.each do |item|
          row = parse_item(item)
          results << row if row
        end

        pageno += 1
      end

      prepare_items(results)
      process_results_batch(results)
    end

    private

    attr_reader :brand

    def parse_item(item)
      title = item.get('ItemAttributes/Title')
      upc = item.get('ItemAttributes/UPC')
      ean = item.get('ItemAttributes/EAN')
      url = item.get('DetailPageURL')
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

      # remove color and size from title
      title.sub!(/,\s#{Regexp.quote size}$/, '') if size
      title.sub!(/,\s#{Regexp.quote color}$/, '') if color
      title.sub!(/\s\(#{Regexp.quote size}, #{Regexp.quote color}\)/, '') if size && color

      gtin = upc || ean

      return unless gtin

      {
        title: title,
        upc: gtin,
        brand: brand,
        category: category,
        price: price.to_i / 100.0,
        price_currency: price_currency,
        color: color,
        size: size,
        url: url,
        image: image,
        source_id: source_id,
        parent_asin: item.get('ParentASIN')
      }
    end

    def send_request(params, attempt=0)
      begin
        params = {
          response_group: :Large,
          search_index: :FashionWomen,
          sort: :price,
        }.merge(params)
        ::Amazon::Ecs.item_search(nil, params)
      rescue ::Amazon::RequestError => e
        raise e if attempt > 5
        send_request(params, attempt+1)
      end
    end

    def self.source_url(brand)
      ::Amazon::Ecs.send(:prepare_url, ::Amazon::Ecs.options.merge({
            brand: brand,
            operation: :ItemSearch, response_group: :Large,
            search_index: :FashionWomen, sort: :price,
            timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}))
    end
  end
end