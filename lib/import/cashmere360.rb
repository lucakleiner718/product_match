class Import::Cashmere360 < Import::Base

  # platform = magento

  def baseurl; 'https://www.360cashmere.com'; end
  def brand; '360 SWEATER'; end

  def perform
    urls = []
    [
      'new-arrivals',
      '360cashmere', #'360cashmere/sweaters', '360cashmere/tops', '360cashmere/accessories-360',
      'skull-cashmere', #'skull-cashmere/sweaters', 'skull-cashmere/accessories', 'skull-cashmere/cannabis',
      'skull-baby',
      'mens',
      'christian-benner-x-skull-cashmere',
      'accessories/shop-all',
    ].each do |cat_link|
      cat_urls = []
      log cat_link
      resp = get_request(cat_link)
      cat_id = resp.body.match(/jQuery\.sdg\.\$currentCategoryId = (\d{1,});/) && $1
      next unless cat_id

      page_no = 1
      while true
        url = "catalog/category/ajax/?id=#{cat_id}&p=#{page_no}&limit=12"
        log url
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        links = html.css('.product-item .product-image a').map{|a| a.attr('href')}
        break if links.size == 0 || (cat_urls & links).size == links.size

        cat_urls += links
        page_no += 1
      end

      puts "cat_urls: #{cat_urls.size}/#{(cat_urls - urls).size}"
      urls += cat_urls
    end

    urls = process_products_urls(urls)

    process_in_batch(urls)
    log "spawned #{urls.size} urls"
  end

  def process_url(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    product_name = html.css('.product-shop h1').first.text.strip
    price = html.css('.regular-price .price').first.text.sub(/^\$/, '')
    currency = 'USD'

    data = {}

    gtins = html.css('script:contains("gsf_associated_products")').first.text
    gtins = gtins.sub(/\A\s+var gsf_associated_products = /m, '').sub(/;\s+\z/m, '').gsub("'", '"').gsub(/ :/, ':').sub(/,\s+}$/, '}')
    gtins_json = JSON.parse(gtins)

    gtins_json.each do |id, upc|
      data[id] ||= {}
      data[id][:upc] = upc
    end

    options1 = html.css('script:contains("new Product.Config(")').first.text
    options1 = options1.sub(/\A\s+var spConfig = new Product\.Config\(/, '').sub(/\);\s+var swatches.+\z/m, '')
    options1_json = JSON.parse(options1)

    options1_json['attributes'].each do |attr_id, attr|
      if attr['code'].in?(%w(color size))
        attr['options'].each do |opt|
          opt['products'].each do |product_id|
            data[product_id][attr['code'].to_sym] = opt['label']
            data[product_id][:price] = opt['oldPrice'] if opt['oldPrice'].to_f > 0
            data[product_id][:price_sale] = opt['price'] if opt['price'].to_f > 0
          end
        end
      end
    end

    style_code = options1_json['productId']

    images = html.css('.owl-stage .owl-item .desktop-only a > img').map{|img| img.attr('src')}.uniq
    images.shift # removed first duplicated image
    main_image = images.shift

    results = []
    data.each do |source_id, row|
      results << {
        title: product_name,
        price: price,
        price_currency: currency,
        color: row[:color],
        size: row[:size],
        upc: row[:upc],
        url: url,
        image: main_image,
        additional_images: images,
        source_id: source_id,
        style_code: style_code,
        brand: brand,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
