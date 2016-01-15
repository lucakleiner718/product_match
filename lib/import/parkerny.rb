class Import::Parkerny < Import::Platform::Venda

  # platform = venda

  def baseurl; 'http://www.parkerny.com'; end
  def brand_name_default; 'Parker'; end

  def perform
    urls = []
    [
      'shop-all/icat/shop-all'
    ].each do |url_part|
      log(url_part)
      perpage = 18
      pagenum = 1
      while true
        url = "#{baseurl}/#{url_part}?setpagenum=#{pagenum}&perpage=#{perpage}"
        resp = get_request(url)
        next if resp.response_code > 200
        html = Nokogiri::HTML(resp.body)

        products = html.css('.search-body .prod .prod-details .prod-name a').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0 || (products.size < perpage * 0.9 && products.size == urls.size)

        urls.concat(products)
        pagenum += 1
      end
    end

    urls = urls.uniq.map{|url| url.sub(/&.*$/, '')}

    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request url
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    style_code = html.css('#invtref').text

    js = html.css('script:contains("Venda.Attributes.StoreJSON")').first.text
    json_str = "[#{js.scan(/Venda\.Attributes\.StoreJSON\(({.*})\);/).map{|el| "[#{el.first}]"}.join(',')}]"
    json = JSON.parse(json_str)

    results = []
    product_name = html.css('#tag-invtname').first.text.strip
    category = html.css('#crumbtrail a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')
    gender = 'Female'

    image_url_mask = "#{baseurl}/content/ebiz/shop/invt/{{style_code}}/{{style_code}}_{{color}}_{{size}}.jpg"
    colors_images = page.scan(/\["([^"]+)"\] = "http:\/\/.*_([^_]+)_setswatch\.jpg"/).each_with_object({}){|el, obj| obj[el[0]] = el[1]}

    json.each do |row|
      options = row[1]
      price = options['atrsell']
      upc = options['atrsku']
      color = options['atr1']
      size = options['atr2']

      next unless colors_images[color]

      image = image_url_mask.gsub('{{style_code}}', style_code).sub('{{color}}', colors_images[color])
      images = [image.sub('{{size}}', 'setlarge'), image.sub('{{size}}', 'setlalt2'), image.sub('{{size}}', 'setlalt3')]
      main_image = images.shift

      results << {
        title: product_name,
        category: category,
        price: price,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        gender: gender,
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
