class Import::Barneys < Import::Platform::Demandware

  # platform = demandware

  def baseurl; 'http://www.barneys.com'; end
  def subdir; 'BNY'; end
  def product_id_pattern; /(\d+)\.html$/i; end

  def perform
    resp = get_request("on/demandware.store/Sites-BNY-Site/default/Designers-ShowJson")
    json = JSON.parse(resp.body)
    brands_links = json.map{|a| a['url'].sub(/^\//, '')}
    brands_links_size = brands_links.size

    page_size = 96
    timestamp = Time.now.to_i

    brands_links.shuffle.each_with_index do |brand_link, index|
      query_params = URI(brand_link).query.split('&').inject({}){|obj, el| k,v = el.split('='); obj[k] = v; obj}
      urls = []
      page_no = 1
      while true
        url = "barneys-new-york?prefn1=brand&prefn2=productAccess&sz=#{page_size}&start=#{(page_no-1) * page_size}&format=page-element&prefv1=#{query_params['prefv1']}&prefv2=isPublic&_=#{timestamp}"
        while true
          log "[URL] #{url}"
          resp = get_request(url)
          log "[EURL] #{resp.effective_url}"
          break if resp.response_code != 403
          log "Sleep"
          sleep 5
        end
        html = Nokogiri::HTML(resp.body)

        links = html.css('.product-tile .product-image a.thumb-link').map{|a| a.attr('href')}
        break if links.size == 0 || (urls & links).size == links.size

        urls += links

        page_no += 1
        break if links.size < page_size
      end

      urls = process_products_urls(urls)
      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "[#{index}/#{brands_links_size}] spawned #{urls.size} urls"
    end
  end

  def process_url(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    raise "Blocked" if resp.response_code == 403
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []
    return false if page =~ /404 Page/i

    script = html.css('script:contains("digitalData = ")').first
    return unless script

    script_text = script.text.strip

    digitalData = script_text.match(/^digitalData = ({.*});?\s+var/m) && $1
    digitalData_json = JSON.parse(normalize_json(digitalData))

    product_name = digitalData_json['product']['StyleInfo']['productName']
    style_code = digitalData_json['product']['StyleInfo']['productID']
    brand = digitalData_json['product']['StyleInfo']['brand']

    if html.css('meta[property="product:price:amount"]').first
      price = html.css('meta[property="product:price:amount"]').first.attr('content')
      currency = html.css('meta[property="product:price:currency"]').first.attr('content')
    elsif
      price = html.css('.product-price .price-sales').first.text
      if price =~ /^\$/
        currency = 'USD'
        price = price.sub(/^\$/, '')
      end
    end

    categories = digitalData_json['page']['category']['primaryCategory'].split('|')

    gender = nil
    if categories[0] == 'women'
      gender = 'Female'
      categories.shift
    elsif categories[0] == 'men'
      gender = 'Male'
      categories.shift
    end

    category = categories.join(' > ')

    images = html.css('#product-image-carousel .item figure img').map{|img| img.attr('src')}
    if images.size == 0
      images = html.css('.product-primary-image img').map{|img| img.attr('src')}
    end
    main_image = images.shift

    digitalData_json['product']['SkuInfo'].each do |item|
      info = item['productInfo']
      upc = info['sku']
      color = info['color']
      size = info['size']

      results << {
        title: product_name,
        brand: brand,
        price: price,
        price_currency: currency,
        category: category,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        gender: gender,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end

  private

  def normalize_json(str)
    str.gsub(/\/\/.*/, '').gsub(/{\s+([a-z])/i, '{\1').gsub(/\s}/, '}').gsub(/,\s+/, ',').gsub(/\[\s+/, '[').gsub(/\s+\]/, ']').gsub(/:\s+"/m, ':"').gsub(/([a-z]+):\s*([{\["])/im, '"\1":\2').gsub('},}', '}}')
  end

  def get_request(url)
    resp = super(url)
    if resp.response_code == 403
      urls = ['sinatra-proxy-dl', 'dlproxy1', 'dlproxy2', 'dlproxy3', 'dlproxy4']
      resp = super("http://#{urls.sample}.herokuapp.com/", url: build_url(url))
    end
    resp
  end
end
