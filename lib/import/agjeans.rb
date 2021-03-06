class Import::Agjeans < Import::Base

  # platform = unknown02
  # platform-pattern - category url has /store/productslist.aspx

  def baseurl; 'http://www.agjeans.com'; end
  def brand_name; 'AG'; end

  def perform
    home_page = get_request('/')
    home_page_html = Nokogiri::HTML(home_page.body)
    categories = home_page_html.css('#globalnav a').map{|a| a.attr('href')}.select{|url| url =~ /^\//}.map{|url| url.match(/\/(\d+)$/) && $1}.compact.uniq.map(&:to_i).sort
    urls = []
    categories.each do |category_id|
      cat_urls = []
      page_no = 1
      total_pages = nil
      while true
        url_part = "/store/productslist.aspx?categoryid=#{category_id}&PageNo=#{page_no}"
        log url_part

        category_page = get_request(url_part).body
        category_page_html = Nokogiri::HTML(category_page)
        page_urls = category_page_html.css('.product-list .item .image-container a').map{|l| l.attr('href').sub(/_c_\d+$/, '')}

        break if page_urls.size == 0

        total_pages ||= category_page_html.css('.pagination .pager .pagfloat').css('a, b').last.text.to_i rescue 1

        break if (cat_urls & page_urls).size == page_urls.size

        cat_urls.concat(page_urls)
        break if total_pages <= page_no

        page_no += 1
      end

      urls.concat(cat_urls)
    end
    urls = urls.uniq.reject{|url| url =~ /\.m4v$/}

    spawn_products_urls(urls)
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
    style_code = cxt[:utag_data][:mfr_number].strip
    categories = cxt[:utag_data][:category].split(':')
    category = categories.first.gsub(/[^a-z]/i, '').downcase
    if category =~ /women/
      gender = 'Female'
    elsif category =~ /men/
      gender = 'Male'
    end
    category = categories.join(' > ')
    product_image = cxt[:utag_data][:product_image]

    upc_js = html.css('script:contains("aUPC")').first.text
    cxt = V8::Context.new
    upc_js = "function reload_sizes(){};window={onload: function(){}}" + upc_js
    mutex { cxt.eval(upc_js) }

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
