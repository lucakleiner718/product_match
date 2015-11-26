class Import::Dionlee < Import::Base

  def baseurl; 'https://www.dionlee.com'; end
  def brand_name; 'Dion Lee'; end
  def brand_name2; 'Line II Dion Lee'; end

  def perform
    [
      'shop/dion-lee', 'shop/dion-lee-ii'
    ].each do |url_part|
      log url_part

      urls = []
      resp = get_request(url_part)
      html = Nokogiri::HTML(resp.body)

      products = html.css('.productItem li > a')
      next if products.size == 0

      urls = process_products_urls products.map{|a| a.attr('href')}

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url url
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    return false if page =~ /404 Page/i

    html = Nokogiri::HTML(page)

    results = []

    style_code = url.match(/\/(\d+)$/)[1]
    product_name = html.css('h1.prodName').first.text
    price = html.css('.priceRRP').text.sub('AUD', '').strip.sub('$' ,'')
    images = html.css('#prodViewsCtn li img').map{|img| img.attr('src')}
    image_main = images.shift
    sizes = html.css('#fisSize option').map{|el| [el.text, el.attr('data-upc')]}

    brand = brand_name
    brand = brand_name2 if url =~ /\/dion-lee-ii\//

    sizes.each do |row|
      results << {
        title: product_name,
        brand: brand,
        price: price,
        price_currency: 'AUD',
        size: row[0],
        upc: row[1],
        url: url,
        image: image_main,
        additional_images: images,
        style_code: style_code,
        gender: 'Female'
      }
    end

    prepare_items(results)
    process_results(results)
  end

  def process_results results
    results.each do |row|
      product = Product.where(source: source, style_code: row[:style_code], size: row[:size]).first_or_initialize
      product.attributes = row
      product.save
    end
  end

end