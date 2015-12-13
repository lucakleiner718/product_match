class Import::Dvf < Import::Platform::Demandware

  def baseurl; 'https://www.dvf.com'; end
  def subdir; 'DvF_US'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end
  def brand_name_default; 'Diane von Furstenberg'; end

  def perform
    [
      'new-arrivals', 'dresses', 'designer-clothing', 'designer-handbags', 'shoes', 'accessories', 'sale'
    ].each do |url_part|
      log url_part
      size = 99
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.search-result-content .product-tile')
        break if products.size == 0

        urls += products.map do |item|
          url = item.css('.product-image a').first.attr('href').sub(/\?.*/, '')
          url = "#{baseurl}#{url}" if url !~ /^http/
          url
        end
      end

      urls = process_products_urls urls

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
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
    product_id_param = product_id.gsub('_', '__').gsub('%2b', '%2B').gsub('+', '%2B')
    url = "#{baseurl}#{url}" if url !~ /^http/

    results = []

    product_name = html.css('#product-content .product-name').first.text.sub(/^dvf/i, '').strip
    category = html.css('.product-breadcrumbs li a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"
    image_url = html.css("#pdp-pinterest-container img").first.attr('src')

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
