class Import::Filson < Import::Base

  # platform = magento

  def baseurl; 'http://www.filson.com'; end
  def brand_name; 'Filson'; end

  def perform
    [
      'men', 'women', 'luggage-bags', 'watches', 'home-camp', 'hunt-fish'
    ].each do |url_part|
      urls = []
      page_number = 1
      while true
        url = "#{url_part}/page/#{page_number}.html"
        log url

        page = get_request(url).body
        html = Nokogiri::HTML(page)

        items = html.css('.products-grid .item a.product-image').map{|l| l.attr('href')}
        break if items.size == 0 || (urls & items).size > 0
        urls.concat items

        page_number += 1
      end

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

    product_name = html.css('.product-name h1').first.text
    style_code = html.css('.product-name .sku-info').text.gsub(/\D/, '')
    gender = nil
    gender = 'Male' if original_url =~ /\/men\//
    gender = 'Female' if original_url =~ /\/women\//

    url = build_url(original_url)
    price = html.css('.product-essential .price-info .price').text.sub('$', '')

    sctipt_tag = html.css('script:contains("sl:translate_json")').first
    return false unless sctipt_tag
    orig_js = sctipt_tag.text
    js = orig_js.strip.sub(/^\(function\(\$,undefined\) {/, '').sub(/}\)\(jQuery\);$/, '').strip
    js = 'window = {location: {href: ""}}; var Product = {Config: function(){}};' + js
    cxt = V8::Context.new
    mutex { cxt.eval(js) }

    cxt[:handler][:config][:products].each do |product|
      row = {
        source_id: product.id,
        upc: product.sku,
        image: product.adc_image.src,
        title: product_name,
        brand: brand_name,
        price: price,
        price_currency: 'USD',
        style_code: style_code,
        gender: gender,
        url: url
      }

      product.options.each do |option|
        if option.option_label =~ /Color/
          row[:color] = option.option_value
        elsif option.option_label =~ /Size/
          row[:size] = option.option_value
        end
      end

      results << row
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
