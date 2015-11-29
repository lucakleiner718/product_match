class Import::Aliceandolivia < Import::Base

  def baseurl; 'http://www.aliceandolivia.com'; end
  def brand_name; 'Alice + Olivia'; end
  IMAGE_PREFIX = "https://s3.amazonaws.com/aliceandolivia-java/images/skus/"

  def perform
    [
      12, 14, 16, 17,
      25, 26,
      30, 32, 33, 34, 35, 36,
      41,
      56, 57, 58, 59,
      62, 63, 65,
      80,
      184
    ].each do |category_id|
      page_number = 1
      per_page = 15
      while true
        url = URI.decode "search/?wt=json&start=#{(page_number-1) * per_page}&rows=#{per_page}&sort=cat_product_sequence_#{category_id}_i+asc&q=attr_cat_id%3A#{category_id}&facet=true&facet.mincount=1&facet.sort=count&facet.field=facet_size&facet.field=facet_color"
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
    orig_js = html.css('script:contains("skuInfos")').first.text
    js_add = init_js(vars: ['optionsSorter'],
      funcs: ['Social', 'optionRenderer', 'ajaxWithoutAuth', 'optionChangeHandler', 'simpleProductOptions'])
    js = "#{js_add};js_site_var = {context_path: ''};$ = function(){};$.cookie = function(){};#{orig_js}"
    cxt.eval(js)

    product_name = html.css('.single-product-description h1').first.text

    cxt['skusInfo']['skuInfos'].each do |item|
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

      images = item['images'].select{|el| el['sizeCode'] == 'IMG_768_1024'}.map{|el| "#{IMAGE_PREFIX}#{el['filename']}"}
      main_image = images.shift
      style_code = page.scan(/pid:'([^']+)'/i).first.first.strip

      results << {
        title: product_name,
        brand: brand_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: item['skuCode'],
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
        gender: :Female,
        source_id: item['itemId']
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
