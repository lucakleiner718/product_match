class Import::Oscardelarenta < Import::Base

  # platform = magento

  def baseurl; 'http://www.oscardelarenta.com'; end
  def brand_name; 'Oscar de la Renta'; end

  def perform
    page = get_request('/')
    html = Nokogiri::HTML(page.body)
    links = html.css('#nav ul li.level-top > a')
    links.each do |link|
      category_url = link.attr('href')
      page_number = 1
      pages_amount = nil
      while true
        cat_url = "#{category_url}?p=#{page_number}"
        log cat_url

        page = get_request(cat_url).body
        html = Nokogiri::HTML(page)

        if page_number == 1
          num_pages = html.css('#num-pages').first
          break unless num_pages
          pages_amount = num_pages.attr('value').to_i
        end

        urls = html.css('.products-grid .item a.product-image').map{|a| a.attr('href')}
        break if urls.size == 0

        urls.each do |url|
          process_url(url.match(/\/([a-z0-9\-]+)$/i) && $1 || url)
        end

        page_number += 1

        break if page_number > pages_amount
      end
    end
  end

  def process_url(url)
    url = build_url url
    log "Processing url: #{url}"
    resp = get_request(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    return false if page =~ /404 Page/i

    cxt = V8::Context.new
    orig_js = html.css('script:contains("sku")').first.text
    js = %|f = function(){}; window = {jQuery: function(){}};VarienForm = f;$ = f;| + orig_js
    cxt.eval(js)
    product_data = cxt['personalShopperProduct']
    product_name = product_data['name']


    cxt = V8::Context.new
    product_config_script = html.css('script:contains("Product.Config")').first
    return unless product_config_script

    orig_js = html.css('script:contains("Product.Config")').first.text
    js = %|f = function(){}; jQuery = function(){return jQuery;}; jQuery.hide = function(){}; window = {jQuery: function(){}};VarienForm = f;$ = f; Product = function(){}; Product.Config = function(){return arguments;};| + orig_js
    cxt.eval(js)
    sizes = {}
    cxt['spConfig'].first.last['attributes'].first.last['options'].each do |el|
      el['products'].each do |prod_id|
        sizes[prod_id] = el['label']
      end
    end
    price = cxt['spConfig'].first.last['oldPrice']
    price_sale = cxt['spConfig'].first.last['basePrice']
    currency = cxt['spConfig'].first.last['template'].scan(/([^#]+)/).first.first
    currency = nil unless currency.in?(['USD', 'RUB', 'EUR'])

    product_data['child_products'].each do |item|
      source_id = item['id']
      upc = item['sku']
      color = item['colour']
      style_code = item['style_number']
      size = sizes[source_id]
      image = item['image']

      results << {
        title: product_name,
        brand: brand_name,
        price: price,
        price_currency: currency,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: image,
        style_code: style_code,
        gender: :Female,
        source_id: source_id
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
