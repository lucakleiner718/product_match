class Import::Marcjacobs < Import::Platform::Demandware

  def baseurl; 'https://www.marcjacobs.com'; end
  def subdir; 'marcjacobs'; end
  def product_id_pattern; /\/([a-z0-9\-\.\+]+)\.html/i; end
  def brand_name_default; 'Marc Jacobs'; end

  def perform
    urls = []

    [
      'women/featured', 'women/ready-to-wear', 'women/bags-wallets',
      'women/shoes', 'women/accessories', 'women/jewelry', 'women/sunglasses',
      'watches',
      'beauty/eyes', 'beauty/lips', 'beauty/face', 'beauty/nails',
      'beauty/fragrance', 'beauty/brushes-cosmetics-cases',
      'children',
      'men/featured', 'men/ready-to-wear', 'men/bags-accessories', 'men/shoes',
      'men/fragrance', 'men/sunglasses',
      'sale'
    ].each do |url_part|
      size = 60
      cat_urls = []
      while true
        url = "#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        log(url)
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('#search-result-items .product-tile')
                     .map{|item| item.css('.product-image a').first.attr('href')}
        break if products.size == 0 || (cat_urls & products).size == products.size

        cat_urls += products

        break if products.size < size
      end

      urls += cat_urls
    end

    spawn_products_urls(urls)
  end

  def process_product(original_url)
    puts "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]
    product_id_param = product_id.gsub('+', '%20').gsub('.', '%2e')
    url = "#{baseurl}#{url}" if url !~ /^http/

    brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = 'Marc Jacobs' if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#product-content .product-name').first.text.strip

    category = html.css('.breadcrumb li a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    colors = html.css('.product-variations .attribute .Color li:not(.visually-hidden)')
    colors.each do |color|
      color_link = color.css('a').first
      color_name = color_link.text
      color_param = "dwvar_#{product_id_param}_color"

      color_id = color_link.attr('href').match(/#{color_param}=([^&]+)\&?/)[1]

      color_url = "#{url}?#{color_param}=#{color_id}"

      image_url = "http://i1.adis.ws/i/Marc_Jacobs/#{product_id_param}_#{color_id}_MAIN?w=340&h=510"

      color_link = internal_url('Product-Variation', pid: product_id_param, "#{color_param}": color_id, format: :ajax)
      detail_color_page = get_request(color_link)
      color_html = Nokogiri::HTML(detail_color_page.body)
      sizes = color_html.css('#va-size option').select{|r| r.attr('value') != ''}

      if sizes.size > 0
        sizes.each do |item|
          size_name = item.text.strip
          size_param = "dwvar_#{product_id_param}_size"
          size_value = item.attr('value').match(/#{size_param}=([^&]+)/i)[1]

          link = internal_url('Product-Variation', pid: product_id_param, "#{size_param}": size_value, "#{color_param}": color_id, format: :ajax)
          size_page = get_request(link)
          next if size_page.response_code != 200

          size_html = Nokogiri::HTML(size_page.body)

          if size_html.css('.price-standard').first
            price = size_html.css('.price-standard').first.text.strip.sub(/^\$|,/, '').sub(',', '')
            price_sale = size_html.css('.price-sales').first.text.strip.sub(/^\$|,/, '').sub(',', '')
          else
            price = size_html.css('.price-sales').first.text.strip.sub(/^\$/, '').sub(',', '')
            price_sale = nil
          end

          upc = size_html.css('#pid').first.attr('value')

          next if upc == product_id
          raise Exception.new("Wrong UPC -> #{upc}") if upc !~ GTIN::REGEXP

          results << {
            title: product_name,
            category: category,
            price: price,
            price_sale: price_sale,
            color: color_name,
            size: size_name,
            upc: upc,
            url: color_url,
            image: image_url,
            style_code: product_id,
            brand: brand_name
          }
        end
      else
        upc = html.css('#pid').first.attr('value')
        price = html.css('.price-sales').first.text.strip.sub(/^\$/, '').sub(',', '')

        results << {
          title: product_name,
          category: category,
          price: price,
          price_sale: nil,
          color: color_name,
          size: nil,
          upc: upc,
          url: url,
          image: image_url,
          style_code: product_id,
          brand: brand_name
        }
      end
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
