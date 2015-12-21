class Import::Theory < Import::Platform::Demandware

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

      spawn_products_urls(urls)
    end
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1].split(',').first

    resp = get_request original_url
    return false if resp.response_code != 200

    url = original_url

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if html.css('.errorpromo').size > 0

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
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
