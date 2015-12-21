class Import::Helmutlang < Import::Platform::Demandware

  def baseurl; 'https://www.helmutlang.com'; end
  def subdir;  'helmutlang_US'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end #F07HM419,default,pd.html
  def brand_name_default; 'Helmut Lang'; end

  def perform
    [
      'womens-all/all-items,default,sc.html', 'mens-all/mens-all,default,sc.html', 'fragrance/fragrance,default,pg.html',
    ].each do |url_part|
      process_category(url_part)
    end
  end

  def process_category(url)
    log url
    resp = get_request(url)
    html = Nokogiri::HTML(resp.body)

    urls = html.css('#search a').map{|a| a.attr('href').sub(/\?.*/, '')}.select{|a| a =~ /[A-Z0-9]+,default,pd\.html$/}

    urls = process_products_urls urls

    urls.each {|url| spawn_url('product', url) }
    log "spawned #{urls.size} urls"
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1].split(',').first

    resp = get_request(original_url)
    return false if resp.response_code != 200

    url = original_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href').sub(/\?.*/, '')

    if canonical_url != url
      url = canonical_url
      product_id = url.match(product_id_pattern)[1].split(',').first
      url = "#{baseurl}#{url}" if url !~ /^http/
    end

    if page.match(/styleID: "([A-Z0-9]+)"/)
      product_id = page.match(/styleID: "([A-Z0-9]+)"/)[1]
    end

    results = []

    product_name = html.css('#pdpMain .product-name').first.text.strip
    images = html.css(".productimages img").map{|img| img.attr('src')}
    image_url = images.shift

    data = get_json product_id
    return false unless data
    data['variations']['variants'].each do |v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']

      results << {
        title: product_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: image_url,
        style_code: product_id,
        brand: brand_name_default
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
