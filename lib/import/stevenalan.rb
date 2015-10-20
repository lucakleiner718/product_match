class Import::Stevenalan < Import::Demandware

  def baseurl; 'http://www.stevenalan.com'; end
  def subdir; 'stevenalan'; end
  def lang; 'default'; end
  def product_id_pattern; /\/([a-zA-Z0-9_\-\.]+)\.html/; end
  def brand_name_default; 'Steven Alan'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'New-Arrivals', 'Women%27s-2', 'Men%27s-2', 'Jewelry', 'Kid%27s', 'Home-Store', 'Sale-1'
    ].each do |url_part|
      puts url_part
      urls = []
      size = 50

      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile .thumb-link').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0

        urls.concat products
      end

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

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    # canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    # if canonical_url != url
    #   product_id = canonical_url.match(product_id_pattern)[1]
    # end

    product_id_param = product_id.gsub('_', '__').gsub('.', '%2e')

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip

    category = nil

    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/#{lang}/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    data = JSON.parse(data_resp.body.strip)

    images = html.css('.attribute .color a').inject({}) do |obj, a|
      color_id = a.attr('href').match(/_color=([^&]*)&/)
      if color_id && color_id[1] && color_id[1].present?
        color_id = color_id[1]
      else
        color_id = html.css('.product-primary-image img').first.attr('src').match(/#{product_id}_([^_]+)_/)[1]
      end
      obj[color_id] = a.attr('data-lgimg').match(/"url":"([^"]+)"/)[1]
      obj
    end

    color_param = "dwvar_#{product_id_param}_color"
    gender = process_title_for_gender(product_name)

    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color = v['attributes']['color'].strip
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"
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
      brand = Brand.create(name: brand_name_default) unless brand
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