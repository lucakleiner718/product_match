class Import::Ramybrook < Import::Base

  # platform = magento

  def baseurl; 'http://www.ramybrook.com'; end
  def brand; 'Ramy Brook'; end

  def perform
    urls = []
    [
      'shop/shop-all/shop-all-ready-to-wear', 'shop/shop-all/shop-all-apres'
    ].each do |cat_link|
      log cat_link
      resp = get_request(cat_link)
      html = Nokogiri::HTML(resp.body)

      links = html.css('.products-grid .item a.product-image').map{|a| a.attr('href')}
      break if links.size == 0

      urls += links
    end
    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    product_name = html.css('.product-name .h1').first.text.strip

    price = html.css('meta[property="product:price:amount"]').first.attr('content')
    currency = html.css('meta[property="product:price:currency"]').first.attr('content')

    data = {}

    gtins = html.css('script:contains("gsf_associated_products")').first.text
    gtins = gtins.sub(/^\s+var gsf_associated_products = /, '').sub(/;\s+$/, '').gsub("'", '"').gsub(/ :/, ':').sub(/,\s+}$/, '}')
    gtins_json = JSON.parse(gtins)

    gtins_json.each do |id, upc|
      data[id] ||= {}
      data[id][:upc] = upc
    end

    options1 = html.css('script:contains("new Product.Config(")').first.text
    options1 = options1.sub(/^\s+var spConfig = new Product\.Config\(/, '').sub(/\);\s+$/, '')
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

    images = html.css('.product-image-gallery img').map{|img| img.attr('src')}.uniq
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
