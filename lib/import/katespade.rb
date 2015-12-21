class Import::Katespade < Import::Platform::Demandware

  def baseurl; 'https://www.katespade.com'; end
  def subdir; 'Shop'; end
  def product_id_pattern; /\/([a-z0-9\-]+)\.html/i; end
  def brand_name_default; 'Kate Spade'; end
  def lang; 'en_US'; end

  def perform
    [
      'new/view-all/', 'handbags/view-all/', 'clothing/view-all/', 'shoes/view-all/',
      'accessories/wallets-wristlets/', 'accessories/jewelry/view-all/',
      'accessories/watches/', 'accessories/cold-weather-accessories/', 'accessories/keychains/', 'accessories/cosmetic-cases/',
      'accessories/tech/', 'accessories/legwear/', 'accessories/fragrance/', 'accessories/sunglasses-glasses/',
      'kids/girls-7-14/', 'kids/toddlers-2-6/', 'babies-layettes-3m-24m/', 'kids/kids-accessories/',
      'home/dining/view-all/', 'home/bedding/', 'home/home-accents-decor/', 'home/desk-stationery/'
    ].each do |url_part|
      log url_part
      url = "#{baseurl}/#{url_part}"
      resp = get_request(url)
      html = Nokogiri::HTML(resp.body)
      elements = html.css('#search-result-items li.grid-tile:not(.oas-tile) .product-tile:not(.product-set-tile)')
      products = elements.select { |item| item.css('.product-price').size == 1 }
      urls = products.map do |item|
        item.css('.product-image a').first.attr('href')
      end

      product_set = elements.select { |item| item.css('.product-set-price').size == 1 }
      product_set.each do |item|
        resp2 = get_request(item.css('.product-image a').first.attr('href'))
        html2 = Nokogiri::HTML(resp2.body)
        urls.concat html2.css('.product-set-list .product-set-item').map{|e| e.css('a.item-name').first.attr('href')}
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
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]

    results = []

    product_name = html.css('.product-name').text.strip
    category = html.css('.breadcrumb li a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    colors = html.css('.product-variations .attribute .Color li:not(.visually-hidden)')
    colors.each do |color|
      color_name = color.css('.title').text
      color_id = color.attr('data-value')
      color_param = color.attr('data-name')

      color_url = "#{url}?#{color_param}=#{color_id}"

      image_url = color.attr('data-pimage')

      color_link = internal_url('Product-Variation', pid: product_id, "#{color_param}": color_id, format: :ajax)
      detail_color_page = get_request(color_link)
      color_html = Nokogiri::HTML(detail_color_page.body)
      sizes = color_html.css('.product-variations .size li:not(.unselectable):not(.visually-hidden) a').select{|r| r.text != '' }

      if sizes.size > 0
        sizes.each do |item|
          size_name = item.text.strip
          size_value = item.attr('href').match(/dwvar_#{product_id}_size=([^&]+)/i)[1]

          link = internal_url('Product-Variation', pid: product_id, "dwvar_#{product_id}_size": size_value, "#{color_param}": color_id, format: :ajax)
          puts link

          size_page = get_request(link)
          next if size_page.response_code != 200

          size_html = Nokogiri::HTML(size_page.body)

          price = size_html.css('.price-sales').first.text.strip.sub(/^\$/, '').sub(',', '')

          upc = size_html.css('#pid').first.attr('value')
          raise Exception.new("Wrong UPC -> #{upc}") if upc !~ /^\d+$/

          results << {
            title: product_name,
            category: category,
            price: price,
            color: color_name,
            size: size_name,
            upc: upc,
            url: color_url,
            image: image_url,
            style_code: product_id,
            brand: brand_name_default
          }
        end
      else
        upc = html.css('#pid').first.attr('value')
        price = html.css('.price-sales').first.text.strip.sub(/^\$/, '').sub(',', '')

        results << {
          title: product_name,
          category: category,
          price: price,
          color: color_name,
          upc: upc,
          url: url,
          image: image_url,
          style_code: product_id,
          brand: brand_name_default
        }
      end
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
