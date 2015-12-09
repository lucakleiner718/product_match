class Import::Donnakaran < Import::Platform::Demandware

  def baseurl; 'http://www.donnakaran.com'; end
  def subdir; 'donnakaran'; end
  def product_id_pattern; /([A-Z0-9]+)\.html/; end
  def brand_name_default; 'Donna Karan'; end

  def perform
    [
      'collection/shop-by-collection/runway', 'collection/shop-by-collection/modern-icons',
      'collection/shop-by-collection/casual-luxe', 'collection/shop-by-collection/pre-fall-2015',
      'collection/shop-by-collection/fall-2015', 'collection/shop-by-collection/resort-2016',
      'collection/features',
      'ready-to-wear/shop-by-category/new-arrivals', 'ready-to-wear/shop-by-category/dresses',
      'ready-to-wear/shop-by-category/cashmere-and-sweaters', 'ready-to-wear/shop-by-category/tops',
      'ready-to-wear/shop-by-category/pants', 'ready-to-wear/shop-by-category/skirts',
      'ready-to-wear/shop-by-category/jackets-and-outerwear', 'ready-to-wear/shop-by-category/evening',
      'accessories/fragrance/view-all-fragrance', 'accessories/fragrance/cashmere-mist',
      'accessories/fragrance/collection-fragrances', 'accessories/fragrance/gift-sets'
    ].each do |url_part|
      log url_part
      size = 60
      urls = []
      while true
        new_urls = []

        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        elements = html.css('#search-result-items li.grid-tile:not(.oas-tile) .product-tile:not(.product-set-tile)')
        products = elements.select { |item| item.css('.product-sales-price').size == 1 }
        new_urls.concat products.map{|item| item.css('.thumb-link').first.attr('href')}

        product_set = elements.select { |item| item.css('.product-set-price').size == 1 }
        product_set.each do |item|
          item_url = item.css('.product-image a').first.attr('href')
          resp2 = get_request item_url
          html2 = Nokogiri::HTML(resp2.body)
          new_urls.concat html2.css('.product-set-list .product-set-item').map{|e| e.css('a.item-name').first.attr('href')}
        end

        break if new_urls.size == 0

        urls.concat new_urls
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
    category = html.css('.breadcrumbs a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"

    image = html.css('.product-image.main-image').first.attr('href')

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
        brand: brand_name_default
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
