class Import::Toryburch < Import::Demandware

  BASEURL = 'https://www.toryburch.com'
  SUBDIR =  'Sites-ToryBurch_US-Site'
  NAME =    'toryburch'
  PRODUCT_ID_PATTERN = /\/([a-z0-9\-\.\+]+)\.html/i

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'clothing/new-arrivals', 'clothing/dresses', 'clothing/jackets-outerwear', 'clothing/pants-shorts',
      'clothing/skirts', 'clothing/sweaters', 'swimwear', 'clothing/tops', 'clothing/t-shirts', 'clothing/tunics',
      'clothing/sale',
      'clothing/the-fall-lookbook', 'clothing/the-paris-collection', 'clothing/seventies-bohemia', 'clothing/travel-chic',
      'clothing/jackets-outerwear',
      'shoes-newarrivals', 'shoes/view-all',
      'handbags/view-all', 'accessories-newarrivals', 'accessories/belts', 'accessories/cosmetic-cases', 'accessories/hats--scarves-gloves',
      'accessories/jewelry', 'accessories/key-fobs', 'accessories/mini-bags', 'accessories/sunglasses-eyewear',
      'accessories/tech-accessories', 'tory-burch-fitbit',
      'accessories/the-wallet-guide', 'accessories/sale',
      'accessories/britten', 'accessories/brody',
      'accessories/fleming', 'accessories/frances', 'accessories/marion',
      'accessories/robinson', 'accessories/york', 'accessories/797',
      'watches', 'home/view-all'
    ].each do |url_part|
      puts url_part
      start = 0
      size = 99
      urls = []
      # binding.pry
      while true
        url = "#{BASEURL}/#{url_part}/?sz=#{size}&start=#{start}&format=ajax"
        resp = get_request(url)
        # resp = Curl.get(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('div.productresultarea div.product.producttile:not(.bannertile)')
        break if products.size == 0

        urls += products.map do |item|
          item.css('.productimage a').first.attr('href').sub(/\?.*/, '')
        end

        start += products.size
        break if url_part.in? ['accessories/the-wallet-guide', 'watches']
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

    resp = Curl.get("#{BASEURL}/#{product_id}.html") do |http|
      http.follow_location = true
    end
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    product_id = url.match(PRODUCT_ID_PATTERN)[1]
    product_id_param = product_id.gsub('+', '%20').gsub('.', '%2e')
    url = "#{BASEURL}#{url}" if url !~ /^http/

    brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = 'Tory Burch' if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#pdp-top .productname').first.text.strip

    category = html.css('#breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    colors = html.css('.variationattribute.color ul.swatchesdisplay li')
    colors.each do |color|
      color_link = color.css('a').first
      color_name = color_link.css('.swatchDispName').text
      color_param = "dwvar_#{product_id_param}_color"
      color_id = color.attr('data-value')

      color_url = "#{url}?#{color_param}=#{color_id}"

      image_url = "http://s7d5.scene7.com/is/image/ToryBurchLLC/TB_#{product_id}_#{color_id}_B?fit=constrain,1&wid=500&hei=700&fmt=jpg"

      color_link = "#{BASEURL}/on/demandware.store/#{SUBDIR}/default/Product-GetVariants?pid=#{product_id_param}&#{color_param}=#{color_id}&format=json"
      detail_color_page = Curl.get(color_link) do |http|
        http.headers['Referer'] = url
        http.headers['X-Requested-With'] = 'XMLHttpRequest'
        http.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36'
      end
      color_json = JSON.parse(detail_color_page.body.strip)

      color_json['variations']['variants'].each do |variant|

        price = variant['pricing']['standard']
        price_sale = variant['pricing']['sale']
        price_sale = nil if price == price_sale
        size = variant['attributes']['size']
        upc = variant['id']

        results << {
          title: product_name,
          category: category,
          price: price,
          price_sale: price_sale,
          color: color_name,
          size: size,
          upc: upc,
          url: color_url,
          image: image_url,
          source_id: product_id,
        }
      end
    end

    # binding.pry

    brand = Brand.get_by_name(brand_name)
    unless brand
      brand = Brand.where(name: 'Tory Burch').first
      brand.synonyms.push brand_name
      brand.save
    end
    source = 'toryburch.com'

    results.each do |row|
      product = Product.where(source: source, source_id: row[:source_id], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end