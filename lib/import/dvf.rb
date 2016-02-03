class Import::Dvf < Import::Platform::Demandware

  def baseurl; 'https://www.dvf.com'; end
  def subdir; 'DvF_US'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end
  def brand_name; 'Diane von Furstenberg'; end

  def perform
    urls = []
    [
      'dresses', 'designer-clothing', 'designer-handbags', 'shoes', 'accessories',
      'sale'
    ].each do |url_part|
      size = 1000
      cat_urls = []
      while true
        url = "#{url_part}/all/?sz=#{size}&start=#{cat_urls.size}&format=ajax"
        log url
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        links = html.css('#search-result-items .product-tile .product-image a.thumb-link').map{|a| a.attr('href')}
        cat_urls += links

        break if links.size < size
      end

      urls += cat_urls
      log "#{cat_urls.size}, #{process_products_urls(cat_urls).size}, #{process_products_urls(urls).size}"
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

    return false if html.css('#error-page').size > 0

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(product_id_pattern)[1]
    product_id_param = product_id.gsub('_', '__').gsub('%2b', '%2B').gsub('+', '%2B')
    url = "#{baseurl}#{url}" if url !~ /^http/

    results = []

    product_name = html.css('#product-content .product-overview-title').first.text.sub(/^dvf/i, '').strip
    category = html.css('.breadcrumbs a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"
    images = html.css("#pdp-image-container .pdp-slider-slide img").map{|img| img.attr('src')}
    main_image = images.shift
    price = html.css('.product-overview-sales-price').first.text

    sizes = html.css('.pdp-default-size-select').first.css('option').map{|opt| opt.attr('value').match(/dwvar_#{product_id_param}_size=([^&$]+)/) && $1}.compact
    colors = html.css('.pdp-default-patterns-wrapper a').map{|color| [color.attr('data-color'), color.attr('title')]}
    color_param = "dwvar_#{product_id_param}_color"

    colors.each do |color_code, color|
      color_url = "#{url}?#{color_param}=#{color_code}"

      sizes.each do |size|

        variant_url = internal_url('Product-Variation', pid: product_id, "dwvar_#{product_id_param}_size" => size, "#{color_param}" => color_code, format: :ajax)
        variant_page = get_request(variant_url)
        variant_html = Nokogiri::HTML(variant_page.body)

        upc = variant_html.css('#pid').first.attr('value')

        results << {
          title: product_name,
          category: category,
          price: price,
          color: color,
          size: size,
          upc: upc,
          url: color_url,
          main_image: main_image,
          additional_images: images,
          style_code: product_id,
          brand: brand_name,
        }
      end
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
