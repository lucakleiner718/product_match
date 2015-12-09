class Import::Ellamoss < Import::Base

  # platform=unknown02

  def baseurl; 'http://www.ellamoss.com'; end
  def brand_name; 'Ella Moss'; end

  def perform
    categories = [
      105, 500, 104, 501, 515, 301, 108, 82, 109, 307, 279, 672, 317,
      136, 139, 137, 138, 350,
    ]
    categories.each do |category_id|
      url_part = "/store/productslist.aspx?categoryid=#{category_id}&PageNo=0"
      log url_part
      urls = []

      category_page = get_request(url_part).body
      category_page_html = Nokogiri::HTML(category_page)
      urls.concat category_page_html.css('.threeGrid .product a.productPic').map{|l| l.attr('href')}

      urls.each {|u| ProcessImportUrlWorker.new.perform self.class.name, 'process_url', u }
      log "spawned #{urls.size}"
    end
  end

  def process_url original_url
    log "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    js = html.css('script:contains("product_image")').first.text
    cxt.eval(js)
    product_name = cxt[:utag_data][:product_name]
    style_code = cxt[:utag_data][:mfr_number]
    category = cxt[:utag_data][:category].gsub(':', ' > ')
    product_image = cxt[:utag_data][:product_image]

    cxt = V8::Context.new
    upc_js = html.css('script:contains("aUPC")').first.text
    cxt.eval("function reload_sizes(){};window={onload: function(){}}" + upc_js)

    data = {}
    cxt[:aUPC].each_with_index do |el, ind1|
      next unless el
      el.each_with_index do |it, ind2|
        next unless it
        data[ind1] ||= []
        data[ind1][ind2] ||= {}
        data[ind1][ind2][:upc] = it
      end
      data[ind1] = data[ind1].select{|el| el.present?}
    end

    cxt[:aSKUUnitCost].each_with_index do |el, ind1|
      next unless el
      el.each_with_index do |it, ind2|
        next unless it
        data[ind1] ||= []
        data[ind1][ind2] ||= {}
        data[ind1][ind2][:price] = it.sub(/\$/, '')
      end
      data[ind1] = data[ind1].select{|el| el.present? && el[:upc].present?}
    end

    cxt[:color_names].to_a.compact.each_with_index do |color, ind|
      data[ind+1].each do |it|
       it[:color] = color
      end
    end

    cxt[:size_names].to_a.compact.each_with_index do |size, ind|
      data.each do |id, el|
        el[ind][:size] = size
      end
    end

    color_images = cxt[:aColor].to_a
    color_images.shift
    color_images.each_with_index do |color_image, ind|
      data[ind+1].each do |it|
        it[:image] = "#{baseurl}/store/ProductImages/details/#{color_image}"
        it[:images] ||= []
        it[:images] << "#{baseurl}/store/ProductImages/details/#{color_image.sub(/_l\.jpg/, '_b.jpg')}"
        it[:images] << "#{baseurl}/store/ProductImages/details/#{color_image.sub(/_l\.jpg/, '_s.jpg')}"
      end
    end

    url = build_url(original_url)

    data.values.flatten.each do |row|
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
        gender: 'Female'
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
