class Import::Ragbone < Import::Platform::Demandware

  def baseurl; 'https://www.rag-bone.com'; end
  def subdir; 'ragandbone'; end
  def product_id_pattern; /([a-z0-9]+)\.html/i; end
  def brand_name_default; 'Rag & Bone'; end

  def perform
    urls = []
    [
      'womens', 'mens', 'sale'
    ].each do |url_part|
      size = 60
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        log(url)
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile')
        break if products.size == 0

        urls += products.map do |item|
          url = item.css('.product-image a').first.attr('href').sub(/\?.*/, '')
          url = "#{baseurl}#{url}" if url !~ /^http/
          url
        end
      end
    end
    spawn_products_urls(urls)
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]
    product_id_param = product_id
    url = "#{baseurl}#{url}" if url !~ /^http/

    results = []
    product_name = html.css('#product-content .product-name').first.text.strip
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"

    gender = nil
    gender = 'Female' if url =~ /\/womens\//
    gender = 'Male' if url =~ /\/mens\//

    data = get_json product_id
    return false unless data
    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"
      image_url = "http://i1.adis.ws/i/rb/#{product_id}-#{color_id}-A.jpg?$socialShare2x$"

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
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
