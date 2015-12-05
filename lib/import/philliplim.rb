class Import::Philliplim < Import::Base

  # platform = unknown3

  def baseurl; 'http://www.31philliplim.com'; end
  def brand_name; '3.1 Phillip Lim'; end
  IMAGE_PREFIX = "https://s3.amazonaws.com/philliplim-java/images/skus/"

  def perform
    [
      6, 14, 15, 87, 21, 53, 118, 23, 24, 102, 31, 54, 29, 32, 33, 143, 137
    ].each do |category_id|
      page_number = 1
      per_page = 15
      while true
        url = URI.decode "search/?wt=json&start=#{(page_number-1) * per_page}&rows=#{per_page}&sort=cat_product_sequence_#{category_id}_i+asc&q=attr_cat_id%3A#{category_id}"
        log url

        json_str = get_request(url).body
        json = JSON.parse(json_str)
        rows = json['response']['docs']

        break if rows.size == 0

        rows.each do |row|
          process_url build_url(row['page_name_s'])
        end

        page_number += 1
      end
    end
  end

  def process_url(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    script_sku = html.css('script:contains("skuInfos")').first
    return unless script_sku
    orig_js = script_sku.text
    js_add = init_js(vars: ['optionsSorter'],
      funcs: ['Social', 'optionRenderer', 'ajaxWithoutAuth', 'optionChangeHandler', 'simpleProductOptions'])
    js = "#{js_add};js_site_var = {context_path: ''};$ = function(){};$.cookie = function(){};#{orig_js}"
    cxt.eval(js)

    product_name = html.css('.product-content .product-content-head h2').first.text.strip

    color_images = {}
    cxt['color_images'].each do |k,v|
      color_images[k] ||= []
      v.each do |image_name, sizes|
        if image_name =~ /product_/i
          color_images[k] << "#{IMAGE_PREFIX}#{sizes['IMG_2000']}"
        end
      end
    end

    cxt['skus']['skuInfos'].each do |item|
      upc = item['skuCode']
      price = item['listPrice']
      price_sale = item['price']

      color = nil
      size = nil
      item['options'].each do |option|
        if option['code'] == 'COLOR'
          color = option['optionValue']['value']
        elsif option['code'] == 'SIZE'
          size = option['optionValue']['value']
        end
      end

      images = color_images[color]
      main_image = images.shift
      style_code = cxt['skus']['productId']
      source_id = item['itemId']

      results << {
        title: product_name,
        brand: brand_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        source_id: source_id
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
