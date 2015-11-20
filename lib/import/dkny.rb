class Import::Dkny < Import::Platform::Demandware

  def baseurl; 'http://www.dkny.com'; end
  def subdir; 'dkny'; end
  def product_id_pattern; /([A-Z0-9]+)\.html/i; end
  def brand_name_default; 'DKNY'; end

  def perform
    [
      'ready-to-wear/women/view-all', 'ready-to-wear/men/view-all',
      'ready-to-wear/features/dkny-pure', 'ready-to-wear/features/the-new-essentials',
      'ready-to-wear/features/best-of-black', 'ready-to-wear/features/runway%3A-fall-2015',
      'ready-to-wear/features/the-coat-shop',
      'bags/bags/view-all', 'shoes/shoes/view-all', 'accessories/accessories/view-all',
    ].each do |url_part|
      log url_part
      size = 50
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('a').map{|a| a.attr('href').sub(/\?.*/, '')}.uniq
        break if products.size == 0

        urls += products
      end

      urls = process_products_urls urls

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
    puts "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]
    product_id_param = product_id
    url = "#{baseurl}#{url}" if url !~ /^http/

    results = []
    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip.sub(/^DKNY\s/, '')
    category = html.css('.breadcrumbs a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    color_param = "dwvar_#{product_id_param}_color"

    colors = html.css('.attribute .Color li a').inject({}) do |obj, a|
      color_id = a.attr('href').match(/_color=([^&]+)/)[1]
      begin
        obj[color_id] = JSON.parse(a.attr('data-lgimg'))['url']
      rescue JSON::ParserError => e
        imgurl = a.to_html.match(/"url":"([^"]+)"/)
        obj[color_id] = imgurl[1] if imgurl
      end
      obj
    end

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
      color = v['attributes']['color']
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"
      image_url = colors[color_id] || colors.first

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
      }
    end

    prepare_items(results)
    process_results(results)
  end

end