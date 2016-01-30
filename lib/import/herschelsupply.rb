class Import::Herschelsupply < Import::Platform::Shopify

  def baseurl; 'http://shop.herschelsupply.com'; end
  def brand_name; 'Herschel Supply Co.'; end
  def source; 'herschelsupply.com'; end

  def perform
    page_no = 1
    while true
      url = "collections/all?page=#{page_no}"
      log url
      page = get_request(url)
      html = Nokogiri::HTML(page.body)

      urls = html.css('.product-row .product li .image-wrapper a').map{|a| a.attr('href')}
      break if urls.size == 0

      urls.each do |url|
        process_product(url)
      end

      page_no += 1
    end
  end

  def process_product(url)
    url = build_url(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    orig_js = html.css('script:contains("Shopify.product =")').first.text
    js = %|Shopify = { product: {} };| + orig_js
    cxt.eval(js)
    product_data = cxt['Shopify']['product']

    style_code = product_data['id']
    product_name = product_data['title']
    category = product_data['type']
    price = product_data['price']
    images = product_data['images'].to_a
    main_image = images.shift

    product_data.variants.each do |variant|
      source_id = variant['id'].to_i.to_s
      color = variant['option2']
      size = variant['option3']
      item_price = variant['price'] || price
      # weight = variant['weight']
      sku = variant['sku']
      upc = variant['barcode']

      results << {
        title: product_name,
        brand: brand_name,
        category: category,
        price: item_price.to_f / 100,
        color: color,
        size: size,
        upc: upc,
        sku: sku,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        source_id: source_id
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
