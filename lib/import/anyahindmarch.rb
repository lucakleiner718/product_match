class Import::Anyahindmarch < Import::Demandware

  def baseurl; 'http://www.anyahindmarch.com'; end
  def subdir; 'anya_uk'; end
  def product_id_pattern; /(\d{13})\.html/i; end
  def brand_name_default; 'Anya Hindmarch'; end

  def perform
    shop_page = get_request("#{baseurl}/Shop")
    shop_page_html = Nokogiri::HTML(shop_page.body)
    categories = shop_page_html.css('#leftcolumn a.refineLink').map{|a| a.attr('href')}
    categories += [
      'Wedding/For-The-Bride-and-Groom', 'Wedding/Honeymoon-and-Travel', 'Wedding/Gifts-for-the-Bridal-Party',
      'Wedding/Planning-and-Organising', 'Clutches'
    ]
    categories.uniq.each do |category_url|
      puts category_url
      start = 0
      size = 20
      urls = []
      while true
        category_url = "#{baseurl}/#{category_url}" if category_url !~ /^http/
        url = "#{category_url}?sz=#{size}&start=#{start}&format=ajaxscroll"

        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.producttile a').map{|a| a.attr('href').sub(/\?.*/, '')}.uniq
        break if products.size == 0 || urls.join('') == products.join('')

        urls += products
        start += products.size
      end

      urls.uniq!

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      puts "spawned #{urls.size} urls"
    end
  end

  def process_url original_url
    puts "Processing url: #{original_url}"
    if original_url =~ product_id_pattern
      product_id = original_url.match(product_id_pattern)[1]
      product_id_ean = true
    else
      product_id = original_url.match(/-([a-z0-9]+)\.html/i)[1]
      product_id_ean = false
    end

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.last_effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if html.css('.notfounddesc').size == 1

    # in case we have link with upc instead of inner uuid of product
    # canonical_url = html.css('link[rel="canonical"]').first.attr('href') if html.css('link[rel="canonical"]').size == 1
    # if canonical_url && canonical_url != url
    #   product_id = url.match(product_id_pattern)[1]
    #   url = "#{baseurl}#{url}" if url !~ /^http/
    # end
    # product_id_param = product_id

    results = []
    product_name = html.css('#pdpMain .productinfo .productname').first.text.strip
    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    color = url.match(/\/([^\/]+)-[a-z0-9]+\.html/i)[1].gsub('-', ' ')
    image_url = page.match(/large:\[\s+\{url: '([^']+)'/)[1]

    if product_id_ean
      pricing = page.match(/"pricing": {"standard": "([^"]+)", "sale": "([^"]+)"/)
      price = pricing[1].to_f
      price_sale = pricing[2].to_f

      ean = product_id
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end

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
    else
      data = get_json product_id
      return false unless data
      data['variations']['variants'].each do |variant|
        ean = variant['id']
        size = variant['attributes']['size']
        price = variant['pricing']['standard']
        price_sale = variant['pricing']['sale']

        results << {
          title: product_name,
          category: category,
          price: price,
          price_sale: price_sale,
          color: color,
          size: size,
          ean: ean,
          url: url,
          image: image_url
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
      product = Product.where(source: source, ean: row[:ean]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id if brand
      product.save
    end
  end

end