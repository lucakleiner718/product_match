class Import::Clubmonaco < Import::Base

  def baseurl; 'https://clubmonaco.borderfree.com'; end
  def brand; 'Club Monaco'; end

  def perform
    page_size = 100

    home_page = get_request('/')
    home_page_html = Nokogiri::HTML(home_page.body)
    categories_ids = home_page_html.css('.flyout-header-menu .cols .col ul li a').map{|a| a.attr('href').scan(/\/family\/index\.jsp\?categoryId=(\d+)/)}.flatten.compact.uniq

    urls = []
    categories_ids.each do |category_id|
      cat_urls = []
      page_no = 1
      pages_amount = nil

      while true
        url = "family/index.jsp?page=#{page_no}&size=#{page_size}&categoryId=#{category_id}"
        log(url)

        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        pages_amount ||= html.css('.pagination a').map{|a| a.text.strip}.select{|a| a =~ /\A\d+\z/}.uniq.sort.last.to_i rescue 1

        links = html.css('#products .product .product-photo a.photo').map{|a| a.attr('href')}
        break if links.size == 0 || (cat_urls & links).size == links.size

        cat_urls += links

        break if pages_amount <= page_no
        page_no += 1
      end

      urls += cat_urls
    end

    spawn_products_urls(urls, false)
  end

  def process_product(url)
    return unless url =~ /index\.jsp\?productId=\d+/

    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    product_name = html.css('h1.product-title').first.text.strip
    style_code = url.match(/productId=(\d+)/)[1]

    results = []

    gtins_script = html.css('script:contains("sku_gtin")').first.text
    js = "var ess = {};" + gtins_script
    cxt = V8::Context.new
    mutex { cxt.eval(js) }

    colors_data = {}
    cxt[:colorSliceValuesGen].each do |color_row|
      item = {
        skus_ids: color_row[:availableSkuIds].to_a,
        images: [
          color_row[:mainImageURL]
        ] + color_row[:alternateViews].map{|av| av[:enhancedImageURL]}
      }

      colors_data[color_row[:colorName]] = item
    end

    cxt[:skusGen].each do |variant|
      sku_id = variant[:sku_id]
      images = [] + colors_data.values.find{|cd| cd[:skus_ids].include?(sku_id)}[:images]
      main_image = images.shift

      results << {
        title: product_name,
        price: variant[:price][:current],
        color: variant[:color],
        size: variant[:size],
        upc: variant[:sku_gtin],
        url: build_url(url),
        image: main_image,
        additional_images: images,
        source_id: sku_id,
        style_code: style_code,
        brand: brand
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
