class Import::Saksfifthavenue < Import::Base

  def baseurl; 'http://www.saksfifthavenue.com'; end

  def get_products_urls
    urls = []
    resp = get_request 'main/ShopByBrand.jsp?tre=sbdnav3'
    html = Nokogiri::HTML(resp.body)
    brands_links = html.css('.designer-list li a').map{|a| a.attr('href').sub(/\?.*/, '')}
    brands_links.each do |link|
      brand_urls = []
      while true
        resp = get_request "#{link}?Nao=#{brand_urls.size}"
        html = Nokogiri::HTML(resp.body)

        products = html.css('.image-container-large a[id^=image-url]').map{|a| a.attr('href')}
        break if products.size == 0

        brand_urls.concat products
      end
      log "added brand urls #{brand_urls.size}"
      urls.concat brand_urls
    end
    urls
  end

  def process_url original_url
    resp = get_request original_url
    html = Nokogiri::HTML(resp.body)

    binding.pry
    script = html.css('script:contains("var mlrs")').text
    json_str = script.strip.sub('var mlrs =', '').strip
    json = JSON.parse(json_str)

    d = json['response']['body']['main_products'].first
    colors = d['colors']['colors'].inject({}){|obj, e| obj[e['color_id']] = e['label']; obj}
    sizes_names = {'SML' => 'Small', 'MED' => 'Medium', 'LRG' => 'Large'}
    sizes = d['sizes']['sizes'].inject({}) do |obj, e|
      value = e['value']
      value = sizes_names[value] if sizes_names[value]
      obj[e['size_id']] = value
      obj
    end
    brand = d['brand_name']['label']
    price = d['price']['list_price'].sub('&#36;', '')
    price_sale = d['price']['on_sale'] && d['price']['sale_price'] ? d['price']['sale_price'].sub('&#36;', '') : nil
    product_name = d['short_description']
    style_code = d['product_id']
    image = "#{d['media']['images_server_url']}#{d['media']['images_path']}#{d['media']['images']['product_detail_image']}"

    results = []

    d['skus']['skus'].each do |v|
      upc = v['upc']
      color = colors[v['color_id']]
      size = sizes[v['size_id']]

      results << {
        title: product_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: original_url,
        image: image,
        style_code: style_code,
        brand: brand
      }
    end

    process_results results
  end

  def process_results results
    results = convert_brand(results)

    results.each do |row|
      product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.save
    end
  end

end