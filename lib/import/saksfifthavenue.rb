class Import::Saksfifthavenue < Import::Base

  def baseurl; 'http://www.saksfifthavenue.com'; end

  def perform
    resp = get_request 'main/ShopByBrand.jsp?tre=sbdnav3'
    html = Nokogiri::HTML(resp.body)
    brands_links = html.css('.designer-list li a').map{|a| a.attr('href').sub(/\?.*/, '')}
    brands_links.each do |link|
      urls = []
      while true
        resp = get_request "#{link}?Nao=#{urls.size}"
        html = Nokogiri::HTML(resp.body)

        products = html.css('.image-container-large a[id^=image-url]').map{|a| a.attr('href')}
        break if products.size == 0

        urls.concat products
      end
      urls.each {|u| process_url u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
    url = URI.decode(original_url).sub(/FOLDER<>folder_id=\d+\&/, '')

    resp = get_request url
    html = Nokogiri::HTML(resp.body)

    cxt = V8::Context.new
    js = html.css('script:contains("var mlrs")').first.text
    cxt.eval(js)

    d = cxt['mlrs']['response']['body']['main_products'].first
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
    additional_images = []
    additional_images << image.sub(/\/(\d+)_(\d+x\d+\.jpg)$/, '/\1_ASTL_\2')
    additional_images << image.sub(/\/(\d+)_(\d+x\d+\.jpg)$/, '/\1_A1_\2')

    results = []

    d['skus']['skus'].each do |v|
      upc = v['upc']
      color = colors[v['color_id']]
      size = sizes[v['size_id']]
      if v['price']
        price = v['price']['list_price'].sub('&#36;', '') if v['price']['list_price'].present?
        price_sale = v['price']['sale_price'].sub('&#36;', '') if v['price']['sale_price'].present?
      end

      results << {
        title: product_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: image,
        additional_images: additional_images,
        style_code: style_code,
        brand: brand
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
