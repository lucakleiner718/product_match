class Import::Canadagoose < Import::Demandware

  def baseurl; 'http://www.canada-goose.com'; end
  def subdir; 'CanadaGooseCA'; end
  def lang; 'default'; end
  def product_id_pattern; /-([A-Z0-9]+)\.html/; end
  def brand_name_default; 'Canada Goose'; end
  def url_prefix_country; 'ca'; end
  def url_prefix_lang; 'en'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'men/parkas', 'men/lightweight', 'men/shells', 'men/accessories',
      'women/parkas', 'women/lightweight', 'women/shells', 'women/accessories',
      'kids/youth', 'kids/kids', 'kids/baby-%26-toddler'
    ].each do |url_part|
      puts url_part
      urls = []

      url = "#{baseurl}/#{url_prefix_country}/#{url_prefix_lang}/#{url_part}/"
      resp = get_request(url)
      html = Nokogiri::HTML(resp.body)

      products = html.css('.product-tile .thumb-link').map{|a| a.attr('href')}.select{|l| l.present?}

      urls.concat products

      urls = urls.map{|url| url =~ /^http/ ? url : "#{baseurl}#{url}"}.map{|url| url.sub(/\?.*/, '') }.uniq

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
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{url_prefix_country}/#{url_prefix_lang}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    # canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    # if canonical_url != url
    #   product_id = canonical_url.match(product_id_pattern)[1]
    # end

    product_id_param = product_id

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip

    category = nil

    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/#{lang}/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    data = JSON.parse(data_resp.body.strip)

    images = html.css('.attribute .Color a').inject({}){|obj, a| obj[a.attr('color')] = a.attr('data-lgimg').match(/"url":"([^"]+)"/)[1] ; obj}

    gender = process_title_for_gender(product_name)

    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color = v['attributes']['Color'].strip
      size = v['attributes']['Size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['Color']
      color_url = url.sub(/#{product_id_param}\.html/, "#{upc}.html")
      image_url = images[color_id]

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
        style_code: product_id,
        gender: gender
      }
    end

    brand = Brand.get_by_name(brand_name)
    unless brand
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end