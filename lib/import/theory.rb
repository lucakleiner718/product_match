class Import::Theory < Import::Demandware

  def baseurl; 'https://www.theory.com'; end
  def subdir;  'Sites-theory_US-Site'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end
  def brand_name_default; 'Theory'; end

  def perform
    [
      'women-shop-all/womens-shop-all,default,sc.html', 'mens-shop-all/mens-shop-all,default,sc.html',
      'accessories-womens-shopall1/accessories-womens-shopall1,default,sc.html',
      'accessories-mens-shopall/accessories-mens-shopall,default,sc.html'
    ].each do |url_part|
      log url_part
      urls = []
      url = "/#{url_part}"
      resp = get_request(url)
      html = Nokogiri::HTML(resp.body)

      products = html.css('#search .product.producttile')

      urls += products.map do |item|
        url = item.css('.productimage a').first.attr('href').sub(/\?.*/, '')
        url = build_url(url)
        url
      end

      urls.uniq!

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1].split(',').first

    resp = get_request original_url
    return false if resp.response_code != 200

    url = original_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    if html.css('link[rel="canonical"]').size == 1
      url = html.css('link[rel="canonical"]').first.attr('href').sub(/\?.*/, '')
      # product_id = url.match(product_id_pattern)[1].split(',').first
      url = "#{baseurl}#{url}" if url !~ /^http/
    end

    if page.match(/styleID: "([A-Z0-9]+)"/)
      product_id = page.match(/styleID: "([A-Z0-9]+)"/)[1]
    end

    results = []

    product_name = html.css('#pdpMain .productname').first.text.strip
    category = html.css('#breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
    # color_param = "dwvar_#{product_id_param}_color"
    images = html.css("#s7container img").map{|img| img.attr('src')}
    image_url = images.shift

    data = get_json product_id
    return false unless data
    data['variations']['variants'].each do |v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']
      # color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = url

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

    process_results results
  end

end