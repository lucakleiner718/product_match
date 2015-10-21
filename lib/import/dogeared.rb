class Import::Dogeared < Import::Demandware

  def baseurl; 'http://www.dogeared.com'; end
  def subdir; 'Dogeared'; end
  def product_id_pattern; /([0-9]{12})\.html/i; end
  def brand_name_default; 'Dogeared'; end
  def lang; 'en_GB'; end

  def perform
    [
      'new', 'must-have', 'necklaces', 'bracelets', 'earrings', 'rings',
      'gifts-wife', 'gifts-mom', 'gifts-daughter', 'gifts-sister', 'gifts-friend', 'gifts-teacher', 'gifts-bridal',
      'gifts-custom', 'gifts-pide-un-deseo', 'gifts-sympathy',
    ].each do |url_part|
      log url_part
      size = 60
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=ajax"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile a').map{|a| a.attr('href').sub(/\?.*/, '')}.uniq
        break if products.size == 0

        urls += products
      end

      urls = process_products_urls urls

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      log "spawned #{urls.size} urls"
    end
  end

  def self.process_url url
    self.new.process_url url
  end

  def process_url original_url
    log "Processing url: #{original_url}"
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

    return false if html.css('#custom-card-greeting').size == 1

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    if canonical_url != url
      product_id = canonical_url.match(product_id_pattern)[1]
    end

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
      data = get_json product_id
      return false unless data
      data.each do |k, v|
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

    process_results results
  end

  def process_results results, brand_name=nil
    brand = Brand.get_by_name(brand_name)
    if !brand && brand_name_default
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name if brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      product = Product.where(source: source, upc: row[:upc]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id if brand
      product.save
    end
  end

end