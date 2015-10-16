class Import::Anyahindmarch < Import::Demandware

  def baseurl; 'http://www.anyahindmarch.com'; end
  def product_id_pattern; /(\d{13})\.html/i; end
  def brand_name_default; 'Anya Hindmarch'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    shop_page = get_request("#{baseurl}/Shop")
    shop_page_html = Nokogiri::HTML(shop_page.body)
    categories = shop_page_html.css('#leftcolumn a.refineLink').map{|a| a.attr('href')}
    categories.each do |category_url|
      puts category_url
      start = 0
      size = 20
      urls = []
      while true
        url = "#{category_url}?sz=#{size}&start=#{start}&format=ajaxscroll"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('a').map{|a| a.attr('href').sub(/\?.*/, '')}.uniq
        break if products.size == 0

        urls += products
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
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    if canonical_url && canonical_url != url
      product_id = url.match(product_id_pattern)[1]
      url = "#{baseurl}#{url}" if url !~ /^http/
    end
    product_id_param = product_id

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []
    product_name = html.css('#pdpMain .productinfo .productname').first.text.strip.sub(/^DKNY\s/, '')
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    pricing = page.match(/"pricing": {"standard": "([^"]+)", "sale": "([^"]+)"/)
    price = pricing[1].to_f
    price_sale = pricing[2].to_f

    color = url.match(/\/([^\/]+)-\d+\.html/)[1].gsub('-', ' ')

    ean = product_id
    if price == 0 && price_sale.present? && price_sale > 0
      price = price_sale
      price_sale = nil
    end
    image_url = page.match(/large:\[\s+\{url: '([^']+)'/)[1]

    results << {
      title: product_name,
      category: category,
      price: price,
      price_sale: price_sale,
      color: color,
      ean: ean,
      url: url,
      image: image_url,
    }

    if brand_name.present?
      brand = Brand.get_by_name(brand_name)
      unless brand
        brand = Brand.where(name: brand_name_default).first
        brand.synonyms.push brand_name
        brand.save if brand.changed?
      end
    end

    results.each do |row|
      product = Product.where(source: source, ean: row[:ean]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end