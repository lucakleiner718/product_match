class Import::Dogeared < Import::Demandware

  def baseurl; 'http://www.dogeared.com'; end
  def subdir; 'Dogeared'; end
  def product_id_pattern; /([0-9]{12})\.html/i; end
  def brand_name_default; 'Dogeared'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'new', 'must-have', 'necklaces', 'bracelets', 'earrings', 'rings',
      'gifts-wife', 'gifts-mom', 'gifts-daughter', 'gifts-sister', 'gifts-friend', 'gifts-teacher', 'gifts-bridal',
      'gifts-custom', 'gifts-pide-un-deseo', 'gifts-sympathy',
    ].each do |url_part|
      puts url_part
      start = 0
      size = 60
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{start}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile a').map{|a| a.attr('href').sub(/\?.*/, '')}.uniq
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
    if original_url =~ product_id_pattern
      product_id = original_url.match(product_id_pattern)[1]
      product_id_gtin = true
    else
      product_id = original_url.match(/\/([a-z0-9]+)\.html/i)[1]
      product_id_gtin = false
    end

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    if canonical_url != url
      product_id = canonical_url.match(product_id_pattern)[1]
    end

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []
    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip.sub(/^DKNY\s/, '')
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    image_url = html.css('.product-image').first.attr('href')

    if product_id_gtin
      upc = product_id
      price = html.css('.price-sales').first.attr('data-price')

      results << {
        title: product_name,
        category: category,
        price: price,
        upc: upc,
        url: url,
        image: image_url,
      }
    else
      variants_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/en_GB/Product-GetVariants?pid=#{product_id}&format=json"
      body = get_request(variants_url).body
      return false if body.blank?
      variants = JSON.parse(body)
      variants.each do |k, v|
        upc = v['id']
        size = v['attributes']['size']
        price = v['pricing']['standard']
        price_sale = v['pricing']['sale']

        results << {
          title: product_name,
          category: category,
          price: price,
          price_sale: price_sale,
          size: size,
          upc: upc,
          url: url,
          image: image_url,
          style_code: product_id
        }
      end
    end


    brand = Brand.get_by_name(brand_name)
    unless brand
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      product = Product.where(source: source, upc: row[:upc]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end