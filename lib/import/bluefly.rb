class Import::Bluefly < Import::Base

  def baseurl; 'http://www.bluefly.com'; end

  def perform
    resp = get_request('search?vl=l&ppp=96')
    html = Nokogiri::HTML(resp.body)
    pages_amount = html.css('.pageNavigation a.paginate').last.text.strip.to_i

    (1..pages_amount).each do |page_no|
      spawn_url('category', "search?vl=l&ppp=96&cp=#{page_no}")
    end
  end

  def process_category(category_url)
    log(category_url)
    resp = get_request(category_url)
    html = Nokogiri::HTML(resp.body)

    urls = html.css('#productGridContainer .listProdImage a').map{|a| a.attr('href')}.uniq
    spawn_products_urls(urls)
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request(url)
    return false unless resp.success?

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if page =~ /404 Page/i

    results = []
    data = {}

    html.css('.pdpSizeListContainer .pdpSizeTile').each do |el|
      upc = el.attr('data-skuid').strip
      size = el.text.strip
      data[upc] = {
        size: size
      }
    end

    product_name = html.css('h2.product-name').first.text
    price = html.css('.skuPriceInfo input[name="finalPrice"]').first.try(:attr, 'value') || html.css('.skuPriceInfo input[name="msrp"]').first.try(:attr, 'value')
    color = html.css('.product-variations .product-variation-label:contains("Color") em').first.text.strip

    images = html.css('.pdpImageContainer a').map{|a| a.attr('rel')}.compact.map{|rel| rel.match(/smallimage: '([^']+)'/) && $1}.compact
    main_image = images.shift

    style_code = html.css('#wishlist_productId').first.attr('value')

    brand = html.css('h1.product-brand').first.text.strip

    binding.pry unless brand
    raise "No Brand" unless brand

    data.each do |upc, row|
      results << {
        title: product_name,
        brand: brand,
        price: price,
        color: color,
        size: row[:size],
        upc: upc,
        url: url,
        image: main_image,
        additional_images: images,
        style_code: style_code,
      }
    end

    prepare_items(results, check_upc_rule: true)
    process_results_batch(results)
  end
end
