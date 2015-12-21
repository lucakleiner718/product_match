class Import::Monicavinader < Import::Base

  def baseurl; 'http://www.monicavinader.com'; end
  def brand_name; 'Monica Vinader'; end

  def perform
    page_no = 1
    while true
      url = build_url("shop?all=true&page=#{page_no}")
      log url
      resp = get_request(url)
      break if resp.effective_url.sub(/\&$/, '') != url
      html = Nokogiri::HTML(resp.body)

      urls = html.css('.product-catalogue__item a.product-listing__link')
                   .map{|a| a.attr('href')}.select{|l| l.present?}
      break if urls.size == 0

      spawn_products_urls(urls)
      page_no += 1
    end
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    product_name = html.css('.pdp-product-intro__title').first.text.strip
    product_subname = html.css('.pdp-product-intro__title .pdp-product-intro__finish').first.text.strip
    product_name = product_name.sub(/#{product_subname}$/, '').strip

    sku = html.css('.pdp-product-intro meta[itemprop="sku"]').first.attr('content').strip
    upc = html.css('.pdp-product-intro meta[itemprop="gtin14"]').first.attr('content').strip
    price = html.css('meta[property="og:price:amount"]').first.attr('content')
    currency = html.css('meta[property="og:price:currency"]').first.attr('content')
    category = html.css('.breadcrumb__list li:not(.is-active) a').inject([]){|ar, el| el.text.downcase.in?(['home']) ? '' : ar << el.text.strip; ar}.join(' > ')

    size = nil
    if html.css('select[name="sizes"]').first
      size = html.css('select[name="sizes"] option[selected]').first.text.sub(/ - In Stock/, '')
    end
    if html.css('.swatches__list .swatches__list-item.is-active').first
      color = html.css('.swatches__list .swatches__list-item.is-active').first.text.strip
    else
      data = page.match(/window\.gaProductData = ({.*,"price":\d+\.?\d*});/) && $1
      data = JSON.parse(data)
      color = data['name'].sub(/#{product_name}$/, '').strip
    end

    images = html.css('.slider__slide.gallery-page img').map{|img| img.attr('srcset').split(',').last.sub(/\d+w$/, '').strip}.reject{|url| url =~ /pdppackagingimage/}
    main_image = images.shift
    source_id = page.match(/product_id\s+=\s+(\d+),/) && $1
    style_code = sku.match(/^([a-z0-9\-]+)-[a-z0-9]+$/i) && $1

    results << {
      title: "#{product_name} / #{product_subname}",
      category: category,
      price: price,
      price_currency: currency,
      # price_sale: price_sale,
      color: color,
      size: size,
      upc: upc,
      sku: sku,
      url: url,
      image: main_image,
      additional_images: images,
      style_code: style_code,
      source_id: source_id,
      brand: brand_name,
    }

    prepare_items(results)
    process_results_batch(results)
  end
end
