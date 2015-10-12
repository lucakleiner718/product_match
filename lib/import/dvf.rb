class Import::Dvf < Import::Demandware

  BASEURL = 'https://www.dvf.com'
  SUBDIR =  'Sites-DvF_US-Site'
  NAME =    'dvf'
  PRODUCT_ID_PATTERN = /\/([^\.\/]+)\.html/
  BRAND_NAME = 'Diane von Furstenberg'
  SOURCE = 'dvf.com'

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'new-arrivals', 'dresses', 'designer-clothing', 'designer-handbags', 'shoes', 'accessories', 'sale'
    ].each do |url_part|
      puts url_part
      start = 0
      size = 99
      urls = []
      binding.pry
      while true
        url = "#{BASEURL}/#{url_part}/?sz=#{size}&start=#{start}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.search-result-content .product-tile')
        break if products.size == 0

        urls += products.map do |item|
          url = item.css('.product-image a').first.attr('href').sub(/\?.*/, '')
          url = "#{BASEURL}#{url}" if url !~ /^http/
          url
        end

        start += products.size
      end

      urls.uniq!

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      puts "spawned #{urls.size} urls"
      # urls.each {|u| ProcessImportUrlWorker.new.perform self.class.name, 'process_url', u }
    end
  end

  def self.process_url url
    self.new.process_url url
  end

  def process_url original_url
    puts "Processing url: #{original_url}"
    product_id = original_url.match(PRODUCT_ID_PATTERN)[1]

    resp = get_request("#{BASEURL}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(PRODUCT_ID_PATTERN)[1]
    product_id_param = product_id.gsub('_', '__').gsub('%2b', '%2B').gsub('+', '%2B')
    url = "#{BASEURL}#{url}" if url !~ /^http/

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = BRAND_NAME# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#product-content .product-name').first.text.sub(/^dvf/i, '').strip
    category = html.css('.product-breadcrumbs li a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
    color_param = "dwvar_#{product_id_param}_color"
    image_url = html.css("#pdp-pinterest-container img").first.attr('src')

    data_url = "#{BASEURL}/on/demandware.store/#{SUBDIR}/default/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    data = JSON.parse(data_resp.body.strip)

    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"

      results << {
        title: product_name,
        category: category,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: color_url,
        image: image_url,
        source_id: product_id,
      }
    end

    if brand_name.present?
      brand = Brand.get_by_name(brand_name)
      unless brand
        brand = Brand.where(name: BRAND_NAME).first
        brand.synonyms.push brand_name
        brand.save if brand.changed?
      end
    end

    results.each do |row|
      product = Product.where(source: SOURCE, source_id: row[:source_id], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end