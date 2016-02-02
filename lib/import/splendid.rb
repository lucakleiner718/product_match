class Import::Splendid < Import::Base

  # platform=unknown02

  def baseurl; 'http://www.splendid.com'; end
  def brand_name; 'Splendid'; end

  def perform
    categories = [
      103, 105, 106, 229, 34, 104, 113, 250, 820, 672, 670, 406,
      133, 134,
      154, 346, 353, 359, 367, 212,
    ]
    categories.each do |category_id|
      url_part = "/store/productslist.aspx?categoryid=#{category_id}&PageNo=0"
      log url_part
      urls = []

      category_page = get_request(url_part).body
      category_page_html = Nokogiri::HTML(category_page)
      urls.concat category_page_html.css('.product-list .item .pic a.product-link').map{|l| l.attr('href')}

      spawn_products_urls(urls)
    end
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i
    gender = nil

    js = html.css('script:contains("product_image")').first.text
    cxt = V8::Context.new
    mutex { cxt.eval(js) }

    product_name = cxt[:utag_data][:product_name]
    # style_code = cxt[:utag_data][:product]
    style_code = cxt[:utag_data][:mfr_number]
    categories = cxt[:utag_data][:category].split(':')
    if categories[0] == 'Womens'
      categories.shift
      gender = 'Female'
    elsif categories[0] == 'Mens'
      categories.shift
      gender = 'Male'
    elsif categories[0] == 'Littles'
      categories.shift
      gender = 'Kids'
    end
    category = categories.join(' > ')
    product_image = cxt[:utag_data][:product_image]

    js = html.css('script:contains("aUPC")').first.text
    js = "function reload_sizes(){};window={onload: function(){}}" + js
    cxt = V8::Context.new
    mutex { cxt.eval(js) }

    data = {}
    cxt[:aUPC].each_with_index do |el, ind1|
      next unless el
      el.each_with_index do |it, ind2|
        next unless it
        data[ind1] ||= {}
        data[ind1][ind2] ||= {}
        data[ind1][ind2][:upc] = it
      end
    end

    cxt[:aSKUUnitCost].each_with_index do |el, ind1|
      next unless el
      el.each_with_index do |it, ind2|
        next unless it
        data[ind1] ||= {}
        data[ind1][ind2] ||= {}
        data[ind1][ind2][:price] = it.sub(/\$/, '')
      end
    end

    cxt[:color_names].to_a.compact.each_with_index do |color, ind|
      data[ind+1].each do |k, it|
        it[:color] = color
      end
    end

    cxt[:size_names].to_a.compact.each_with_index do |size, ind|
      data.each do |id, el|
        el[ind+1][:size] = size
      end
    end

    data = data.inject({}) do |d_obj, (index, rows)|
      d_obj[index] = rows.select{|k, v| v[:upc].present?}
      d_obj
    end

    color_images = cxt[:aColor].to_a
    color_images.shift
    color_images.each_with_index do |color_image, ind|
      data[ind+1].each do |ind, it|
        it[:image] = "#{baseurl}/store/ProductImages/details/#{color_image}"
        it[:images] ||= []
        it[:images] << "#{baseurl}/store/ProductImages/details/#{color_image.sub(/_l\.jpg/, '_b.jpg')}"
        it[:images] << "#{baseurl}/store/ProductImages/details/#{color_image.sub(/_l\.jpg/, '_s.jpg')}"
      end
    end

    url = build_url(original_url)

    elements = data.values.map{|obj| obj.values}.flatten
    elements.each do |row|
      results << {
        title: product_name,
        brand: brand_name,
        category: category,
        price: row[:price],
        price_sale: row[:price_sale],
        color: row[:color],
        size: row[:size],
        upc: row[:upc],
        url: url,
        image: row[:image] || product_image,
        additional_images: row[:images],
        style_code: style_code,
        gender: gender
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
