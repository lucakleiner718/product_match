class Import::Stevenalan < Import::Platform::Demandware

  def baseurl; 'http://www.stevenalan.com'; end
  def subdir; 'stevenalan'; end
  def lang; 'default'; end
  def product_id_pattern; /\/([^\/]+)\.html/; end
  def brand_name_default; 'Steven Alan'; end

  def perform
    [
      'New-Arrivals', 'Women%27s-2', 'Men%27s-2', 'Jewelry', 'Kid%27s', 'Home-Store', 'Sale-1'
    ].each do |url_part|
      log url_part
      urls = []
      size = 50

      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile .thumb-link').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0

        urls.concat products
      end

      spawn_products_urls(urls)
    end
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    return false if page =~ /PAGE NOT FOUND/i
    html = Nokogiri::HTML(page)

    product_id_param = product_id.gsub('_', '__').gsub('.', '%2e')

    results = []

    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip

    category = nil

    images = html.css('.attribute .color a').inject({}) do |obj, a|
      color_id = a.attr('href').match(/_color=([^&]*)&/)
      if color_id && color_id[1] && color_id[1].present?
        color_id = color_id[1]
      else
        product_id_image = product_id.gsub('.', '').gsub('%2F', '').gsub('%27', '')
        color_id = html.css('.product-primary-image img')
                     .first.attr('src').match(/#{product_id_image}_([^_]+)_/)[1]
      end
      obj[color_id] = a.attr('data-lgimg').match(/"url":"([^"]+)"/)[1]
      obj
    end

    color_param = "dwvar_#{product_id_param}_color"
    gender = process_title_for_gender(product_name)

    data = get_json product_id
    return false unless data
    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color = v['attributes']['color'].try(:strip)
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"
      image_url = images[color_id]

      results << {
        title: product_name,
        category: category,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: color_url,
        image: image_url,
        style_code: product_id,
        gender: gender,
        brand: brand_name_default
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
