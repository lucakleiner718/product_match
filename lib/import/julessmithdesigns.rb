class Import::Julessmithdesigns < Import::Platform::Shopify

  def baseurl; 'http://julessmithdesigns.com'; end
  def brand_name; 'Jules Smith'; end

  def perform
    page_no = 1
    while true
      page_url = "collections/all?page=#{page_no}"
      log page_url
      page = get_request(page_url)
      html = Nokogiri::HTML(page.body)

      urls = html.css('.thumbnail a').map{|a| a.attr('href')}
      break if urls.size == 0

      urls.each do |url|
        process_product(url)
      end

      page_no += 1
    end
  end

  def process_product(url)
    url = build_url url
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    js_script =  html.css('script:contains("Shopify.OptionSelectors")').first
    return unless js_script
    orig_js = js_script.text

    js = orig_js.sub(/^\s+#{Regexp.quote " // <![CDATA["}\s+#{Regexp.quote "$(function() {"}\s+/, '').sub(/\s+#{Regexp.quote "});"}\s+#{Regexp.quote "// ]]>"}\s+$/, '')
    js = %|$ = function(func){console = {log: function(){}}; return typeof(func) == 'function' ? function(){return {val: function(){return {trigger: function(){}}}}} : {val: function(){return {trigger: function(){}}}}}; selectCallback_new = ''; Shopify = { linkOptionSelectors: function(){}, OptionSelectors: function(){ Shopify.product = arguments } };selectCallback = function(){};| + js
    cxt.eval(js)
    product_data = cxt['Shopify']['product'][1]['product']

    style_code = product_data['id']
    product_name = product_data['title']
    category = product_data['type']
    price = product_data['price']
    images = product_data['images'].to_a
    main_image = images.shift

    product_data.variants.each do |variant|
      source_id = variant['id'].to_i.to_s
      color = variant['option2']
      size = variant['option1']
      item_price = variant['price'] || price
      # weight = variant['weight']
      sku = variant['sku']
      upc = variant['barcode']

      results << {
        title: product_name,
        brand: brand_name,
        category: category,
        price: item_price.to_f / 100,
        color: color,
        size: size,
        upc: upc,
        sku: sku,
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
