require 'open-uri'

class Import::Kenzo < Import::Demandware

  def baseurl; 'https://www.kenzo.com'; end
  def subdir; 'Kenzo'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end
  def brand_name_default; 'Diane von Furstenberg'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'merry-k',
      'women', 'men', 'kids'
    ].each do |url_part|
      puts url_part
      urls = []

      url = "#{baseurl}/en/#{url_part}"
      resp = open(url)
      html = Nokogiri::HTML(resp)

      html.css('.category').each do |categ|
        items = categ.attr('data-template-items')
        items_html = Nokogiri::HTML(open(items).read)
        urls += items_html.css('a.product').map{|link| link.attr('href')}

        intro = categ.attr('data-template-intro')
        intro_html = Nokogiri::HTML(open(intro).read)
        urls += intro_html.css('a.product').map{|link| link.attr('href')}
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
    binding.pry
    puts "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = open("#{baseurl}/en/#{product_id}.html")
    return false if resp.status.first.to_i != 200

    url = original_url

    page = resp.read
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = baseurl + html.css('link[rel="canonical"]').first.attr('href')
    if canonical_url != url
      url = canonical_url
      product_id = url.match(product_id_pattern)[1]
      url = "#{baseurl}#{url}" if url !~ /^http/
    end

    product_id_param = product_id

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#content .title h1').first.text.strip

    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')

    color_param = "dwvar_#{product_id_param}_color"

    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/default/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = open(data_url)
    data = JSON.parse(data_resp.read.strip)

    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['color']
      color_url = "#{url}?#{color_param}=#{color_id}"
      image_url = "http://i1.adis.ws/i/rb/#{product_id}-#{color_id}-A.jpg?$socialShare2x$"

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
        brand = Brand.where(name: brand_name_default).first
        brand.synonyms.push brand_name
        brand.save if brand.changed?
      end
    end

    results.each do |row|
      product = Product.where(source: source, source_id: row[:source_id], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id
      product.save
    end

    results
  end

end