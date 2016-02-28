class Import::Vitaminaswim < Import::Base

  # platform = wordpress

  def baseurl; 'https://vitaminaswim.com'; end
  def brand; 'Vitamin A'; end

  def perform
    resp = get_request('shop')
    html = Nokogiri::HTML(resp.body)

    urls = html.css('.grid.products .grid__item a').map{|a| a.attr('href')}.select{|l| l.present?}

    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"

    resp = get_request(url)
    return false if resp.response_code != 200

    html = Nokogiri::HTML(resp.body)

    results = []

    # product_name = resp.body.match(/'name': '([^']+)'/) && $1
    product_name = html.css('h1.product__title').first.text
    category = resp.body.match(/'category': '([^']+)'/) && $1
    color = nil
    if html.css('h1.product__title .h5').size == 1
      color = html.css('h1.product__title .h5').text
    end
    images = html.css('.product__image--thumbnails a.zoom').map{|a| a.attr('href')}
    main_image = images.shift

    html.css('form.variations_form').each do |form|
      if form.css(' > .grid > .grid__item').first
        product_name, color = form.css(' > .grid > .grid__item').first.text.split(' – ', 2)
      end

      price = html.css('meta[itemprop="price"]').first.attr('content')
      price_currency = html.css('meta[itemprop="priceCurrency"]').first.attr('content')
      price_sale = nil
      style_code = form.attr('data-product_id')

      variants = JSON.parse(form.attr('data-product_variations'))

      variants.each do |variant|
        source_id = variant['variation_id']
        price = variant['display_regular_price'] || price
        price_sale = variant['display_price'] || price_sale
        upc = variant['sku']
        size = nil
        variant['attributes'].each do |k, v|
          if k.in?(['attribute_pa_size-for-standard-bottoms', 'attribute_pa_sizes-for-standard-tops'])
            values = Hash[form.css("select[name='#{k}'] option").map{|o| [o.attr('value'), o.text]}.select{|o| o[0].present?}]
            size = values[v] || v.titleize.upcase
          end
        end

        results << {
          title: product_name,
          price: price,
          price_currency: price_currency,
          price_sale: price_sale,
          color: color,
          size: size,
          upc: upc,
          url: url,
          image: main_image,
          additional_images: images,
          style_code: style_code,
          brand: brand,
          category: category,
          source_id: source_id
        }
      end
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
