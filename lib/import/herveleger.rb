class Import::Herveleger < Import::Demandware

  def baseurl; 'http://www.herveleger.com'; end
  def subdir; 'HerveLeger'; end
  def product_id_pattern; /([A-Z0-9\-]+)\.html/i; end
  def brand_name_default; 'Herve Leger'; end

  def perform
    [
      'NEW-ARRIVALS/just-in-new-arrivals,default,sc.html', 'THE-PRE-SPRING-COLLECTION/runway-resort,default,sc.html',
      'EVENT-DRESSING/just-in-event,default,sc.html',
      'DRESSES/dresses,default,sc.html', 'SIGNATURE/signature,default,sc.html', 'CLOTHING/clothing,default,sc.html',
      'ACCESSORIES/accessories,default,sc.html', 'FALL-2015/runway-fall,default,sc.html',
      'PRE-FALL-2015/runway-pre-fall,default,sc.html',
      'SUMMER-2015/runway-summer,default,sc.html', 'THE-PRE-SPRING-COLLECTION/runway-resort,default,sc.html',
      'SALE/sale,default,sc.html'
    ].each do |url_part|
      log url_part
      start = 0
      size = 50
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{start}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile a').map{|a| a.attr('href')}.select{|l| l.present?}.map{|a| a.sub(/\?.*/, '')}.uniq
        break if products.size == 0

        urls += products
        start += products.size
      end

      urls.uniq!

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
    log "Processing url: #{original_url}"

    # format like: http://www.herveleger.com/Carmen-Woodgrain-Foil-Bandage-Dress/HUN6W073-F6K,default,pd.html"
    if original_url =~ /\/[a-z0-9\-]+,[a-z\,]+\.html$/i
      url = original_url
      product_id = original_url.match(/\/([a-z0-9\-]+),[a-z\,]+\.html$/i)[1]
      resp = get_request(url)
    else
      product_id = original_url.match(product_id_pattern)[1]

      resp = get_request("#{baseurl}/#{product_id}.html")
      return false if resp.response_code != 200

      url = resp.last_effective_url
    end

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    if canonical_url != url
      product_id = url.match(product_id_pattern)[1]
      url = "#{baseurl}#{url}" if url !~ /^http/
    end

    product_id_param = product_id

    results = []
    # product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip.sub(/^DKNY\s/, '')
    product_name = page.match(/app\.page\.setContext\(\{"title":"([^"]+)"/)[1]
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    color_param = "dwvar_#{product_id_param}_color"

    colors = html.css('.attribute .Color li a').inject({}) do |obj, a|
      color_id = a.attr('href').match(/_color=([^&]*)/)[1]
      if color_id.blank?
        color_id = product_id.match(/-([a-z0-9]+)$/i)[1]
      end
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

    process_results results
  end

end