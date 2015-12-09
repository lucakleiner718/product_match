class Import::Rvca < Import::Base

  def baseurl; 'http://www.rvca.com'; end
  def brand_name; 'RVCA'; end

  def perform
    urls = []
    [
      'mens-all-products', 'womens-all-products', 'va-sport-all-products', 'boys-all-products'
    ].each do |url_part|
      url_part = "shop/#{url_part}"
      log url_part

      category_page = get_request(url_part).body
      category_page_html = Nokogiri::HTML(category_page)
      urls += category_page_html.css('.products-list .product-wrapper a.product-image').map{|l| l.attr('href')}
      log "urls amount #{urls.size}"
    end
    urls = process_products_urls(urls)
    log "uniq urls #{urls.size}"
    urls.each {|u| ProcessImportUrlWorker.new.perform self.class.name, 'process_url', u }
  end

  def process_url url
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    js = html.css('script:contains("dataLayer =")').first.text
    cxt.eval(js)
    data = cxt['dataLayer'].first

    return unless data['product']

    product_name = data['product']['name']
    style_code = data['product']['sku']
    material = data['product']['materials']
    categories = data['product']['category_path'].to_a
    gender = nil
    if categories.include?('Mens')
      gender = 'Male'
      categories -= ['Mens']
    end
    colors = html.css('#Color option').inject({}){|obj, el| obj[el.text] = el.attr('value'); obj}

    if data['product']['variations']
      data['product']['variations'].each do |variant|
        upc = variant['upc'].gsub(/^0+/, '')
        color = variant['color']
        color_code = colors[color]
        size = variant['size']
        price = variant['original_price']
        price_sale = variant['price']
        image = html.css('.images.product-thumbnails[data-color="'+color_code+'"] a').first.attr('data-large')

        results << {
          title: product_name,
          brand: brand_name,
          category: categories.join(' > '),
          price: price,
          price_sale: price_sale,
          color: color,
          size: size,
          upc: upc,
          url: build_url(url) + "?color=#{color_code}",
          image: build_url(image),
          style_code: style_code,
          gender: gender,
          material: material
        }
      end
    elsif data['product']['upc'].present?
      upc = data['product']['upc'].gsub(/^0+/, '')
      color = data['product']['color']
      size = data['product']['size']
      price = data['product']['original_price']
      price_sale = data['product']['price']
      image = html.css('.images.product-thumbnails a').first.attr('data-large')

      results << {
        title: product_name,
        brand: brand_name,
        category: categories.join(' > '),
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: build_url(url),
        image: build_url(image),
        style_code: style_code,
        gender: gender,
        material: material
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
