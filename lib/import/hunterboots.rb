class Import::Hunterboots < Import::Base

  def baseurl; 'http://www.hunterboots.com'; end
  def brand_name_default; 'Hunter Boots'; end

  def perform
    urls = []
    [
      'womens-new-arrivals', 'womens-wellington-boots', 'womens-footwear', 'womens-clothing', 'womens-bags',
      'womens-accessories', 'womens-gifting',
      'mens-new-arrivals', 'mens-wellington-boots', 'mens-footwear', 'mens-clothing', 'mens-bags', 'mens-accessories',
      'mens-gifts', 'mens-collections',
      'kids-new-arrivals', 'kids-boots-wellingtons', 'kids-welly-accessories', 'kids-gifting', 'kids-collections',
    ].each do |url_part|
      page_no = 1
      cat_urls = []
      while true
        url = "#{url_part}/?page=#{page_no}"
        log url
        url = build_url(url)

        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        links = html.css('.category-product a.category-product-block__image-link').map{|a| a.attr('href')}.uniq
        break if links.size == 0 || (cat_urls & links).size == links.size
        cat_urls += links
        page_no += 1
      end
      urls += cat_urls

      log "total #{urls.size}/#{urls.uniq.size} urls"
    end

    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    title_box = html.css('div.title[itemprop="name"]').first
    product_name = title_box.css('.product-page-info__title[itemprop="name"]').first.text.strip
    currency = title_box.css('span[itemprop="priceCurrency"]').first.attr('content')
    price = title_box.css('.product-page-info__title[itemprop="price"]').first.attr('content')
    color = html.css('.product-page-info__option:contains("Colour")').first.css('.value').text
    images = html.css('.product-page-main__image .product-image-wrapper').map{|el| el.css('img').first.attr('src')}
    main_image = images.shift

    html.css('.product-page-info__sizes .product-page-info__size').each do |size_item|
      upc = size_item.css('input[type="radio"]').first.attr('value')
      size = size_item.css('label').text.strip
      style_code = url.match(/\/(\d+)$/) && $1

      results << {
        title: product_name,
        price: price,
        price_currency: currency,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        brand: brand_name_default
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
