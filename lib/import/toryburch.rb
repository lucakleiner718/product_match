class Import::Toryburch < Import::Platform::Demandware

  def baseurl; 'http://www.toryburch.com'; end
  def subdir; 'ToryBurch_US'; end
  def product_id_pattern; /\/([a-z0-9\-\.\+]+)\.html/i; end
  def brand_name_default; 'Tory Burch'; end

  def perform
    [
      'clothing/new-arrivals', 'clothing/dresses', 'clothing/jackets-outerwear', 'clothing/pants-shorts',
      'clothing/skirts', 'clothing/sweaters', 'swimwear', 'clothing/tops', 'clothing/t-shirts', 'clothing/tunics',
      'clothing/sale',
      'clothing/the-fall-lookbook', 'clothing/the-paris-collection', 'clothing/seventies-bohemia', 'clothing/travel-chic',
      'clothing/jackets-outerwear',
      'shoes-newarrivals', 'shoes/view-all',
      'handbags/view-all', 'accessories-newarrivals', 'accessories/belts', 'accessories/cosmetic-cases', 'accessories/hats--scarves-gloves',
      'accessories/jewelry', 'accessories/key-fobs', 'accessories/mini-bags', 'accessories/sunglasses-eyewear',
      'accessories/tech-accessories', 'tory-burch-fitbit',
      'accessories/the-wallet-guide', 'accessories/sale',
      'accessories/britten', 'accessories/brody',
      'accessories/fleming', 'accessories/frances', 'accessories/marion',
      'accessories/robinson', 'accessories/york', 'accessories/797',
      'watches',
    ].each do |url_part|
      log url_part
      size = 99
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('div.productresultarea div.product.producttile:not(.bannertile)')
        break if products.size == 0

        urls += products.map do |item|
          item.css('.productimage a').first.attr('href').sub(/\?.*/, '')
        end

        break if url_part.in? ['accessories/the-wallet-guide', 'watches']
      end

      spawn_products_urls(urls)
    end
  end

  def process_product(original_url, allow_spawn=true)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{product_id}.html")
    return false unless resp.success?

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if html.css('#pdp-top').size == 0

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]
    # product_id_param = product_id.gsub('+', '%20').gsub('.', '%2e')
    url = "#{baseurl}#{url}" if url !~ /^http/

    results = []

    product_name = nil
    brand_name = nil

    category = html.css('#breadcrumb a').map{|el| el.text.strip}.inject([]){|ar, el| el == 'Home' ? '' : ar << el; ar}.join(' > ')

    colors = {}
    script = html.css('script:contains("new app.Product"):contains("variations")').first.text
    if html.css('.subproduct').size > 0 && script =~ /app\.ProductCache/
      json_str = script.match(/new app.Product\({\s+data:\s+({.*})\s+}\);\s+app\.ProductCache/m)[1]
    else
      json_str = script.match(/new app.Product\({\s+data:\s+({.*})\s+}\);\s+\}\);/m)[1]
    end
    json = JSON.parse(json_str) rescue nil
    if json
      product_name = json['name']
      brand_name = json['brand']
      json['variations']['attributes'].each do |attribute|
        if attribute['id'] == 'color'
          colors = attribute['vals'].inject({}){|obj, el| obj[el['id']] = el['val']; obj}
        end
      end
    end

    product_name = html.css('#pdp-top .productname').first.text.strip unless product_name

    colors = html.css('.variationattributes .color li').inject({}) do |obj, li|
      color_id = li.attr('data-value')
      color_name = li.css('a').text.strip
      obj[color_id] = color_name
      obj
    end if colors.size == 0

    if allow_spawn && html.css('.subproduct').size > 0
      html.css('.subproduct').map{|el| el.attr('id').match(/product-(.*)/)[1]}.each do |subproduct_id|
        url = build_url("#{subproduct_id}.html")
        spawn_url('product', url, false)
      end
    end

    brand_name = page.match(/"brand":\s"([^"]+)"/)[1] unless brand_name
    brand_name = nil if brand_name.downcase == 'n/a'

    data = get_json product_id
    return false unless data
    data['variations']['variants'].each do |v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color_id = v['attributes']['color']
      color = colors[color_id]
      size = v['attributes']['size']
      color_url = "#{url}?dwvar_#{product_id}_color=#{color_id}"

      images = []
      ['', 'A', 'B', 'C', 'D', 'E', 'F'].each do |letter|
        image_url = "http://s7d5.scene7.com/is/image/ToryBurchLLC/TB_#{product_id}_#{color_id}#{letter.present? ? "_#{letter}" : ''}?fit=constrain,1&wid=500&hei=700&fmt=jpg"
        resp_img = get_request(image_url)
        # 9190 bytes is the size of default image
        images << image_url if resp_img.success? && resp_img.body.size != 9190
      end
      main_image = images.shift

      results << {
        title: product_name,
        category: category,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: color_url,
        image: main_image,
        additional_images: images,
        style_code: product_id,
        brand: brand_name
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
