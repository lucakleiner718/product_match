class Import::Lipsy < Import::Base

  def baseurl; 'http://www.lipsy.co.uk'; end

  def perform
    resp = Typhoeus::Request.new(
      'http://www.lipsy.co.uk/Webservices/CategoryService.svc/GetProducts',
      method: :post,
      body: {
        filter: "pricegbp-0.0-1000.0|",
        firstItem: '0',
        pagesize: "0",
        showall: "true",
        sortoption: "",
        url: "http://www.lipsy.co.uk/store/brands#pagesize=72",
      }.to_json,
      headers: {
        'Content-Type' => 'application/json; charset=UTF-8',
      }
    ).run

    json = JSON.parse(resp.body)
    html = Nokogiri::HTML(json['d']['DisplayControl'])
    urls = html.css('.product a').map{|a| a.attr('href')}.uniq

    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    data = {}

    html.css('div[itemprop="offers"]').each do |el|
      source_id = el.css('meta[itemprop="sku"]').first.attr('content')
      data[source_id] = {
        upc: el.css('meta[itemprop="gtin13"]').first.attr('content').strip,
        price: el.css('meta[itemprop="price"]').first.attr('content'),
        price_currency: el.css('meta[itemprop="priceCurrency"]').first.attr('content'),
      }
    end

    html.css('.sizeSelectors .sizeOption').each do |el|
      source_id = el.attr('data-value').split('|').first
      data[source_id][:size] = el.text
    end

    color = html.css('.colourText p[itemprop="color"]').first.text.strip

    product_currency = nil
    product_name = html.css('h1[itemprop="name"]').first.text.strip
    product_price = html.css('h2.product-price').first.text
    if product_price =~ /£/
      product_price.sub!('£', '')
      product_currency = "GBP"
    end

    images = html.css('#divProductImages a.cloud-zoom-gallery').map{|a| a.attr('href')}
    main_image = images.shift

    style_code = html.css('div.colourText:contains("Product Code") p').first.text.strip

    breadcrumbs = CGI.unescapeHTML(html.css('#hdnBreadCrumb').first.attr('value'))
    breadcrumbs_items = Nokogiri::HTML(breadcrumbs).text.split('/').map(&:strip)
    breadcrumbs_brand = breadcrumbs_items - ['Home', 'Brands', product_name]
    brand = nil
    if breadcrumbs_items.size - 3 == 1 && breadcrumbs_brand.size == 1
      brand = breadcrumbs_brand.first
    end
    unless brand
      brand_slug = url.match(/\/store\/([^\/]+)\//) && $1
      brand = html.css(".nav-column li a[href*=\"/store/brands/#{brand_slug}\"]").map{|a| a.text}.first
      brand = html.css(".nav-column li a[href*=\"/store/dresses/#{brand_slug}\"]").map{|a| a.text}.first unless brand
      brand = page.match(/href="http:\/\/www\.lipsy\.co\.uk\/store\/Brands\/#{Regexp.quote brand_slug}" title="([^"]+)"/) && $1 unless brand
    end

    binding.pry if !brand && Rails.env.development?
    raise "No Brand" unless brand

    data.each do |source_id, row|
      results << {
        title: product_name,
        brand: brand,
        # category: category,
        price: (row[:price] || product_price),
        price_currency: (row[:price_currency] || product_currency),
        color: color,
        size: row[:size],
        upc: row[:upc],
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        gender: :Female,
        source_id: source_id,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
