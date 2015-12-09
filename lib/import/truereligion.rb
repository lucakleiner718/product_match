class Import::Truereligion < Import::Platform::Demandware

  def baseurl; 'http://www.truereligion.com'; end
  def subdir; 'TrueReligion'; end
  def product_id_pattern; /([A-Z0-9]+)\.html/; end
  def brand_name_default; 'True Religion'; end

  def perform
    [
      'mens', 'womens', 'kids',
    ].each do |url_part|
      log url_part
      size = 60
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile .thumb-link').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0

        urls.concat products
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

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    if canonical_url != url
      product_id = canonical_url.match(product_id_pattern)[1]
    end

    product_id_param = product_id

    results = []
    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"

    images = html.css('.product-primary-image img').map{|img| img.attr('src')}
    image = images.shift

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
      color = v['attributes']['color'].strip
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
        image: image,
        style_code: product_id,
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
