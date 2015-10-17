require 'open-uri'
class Import::Helmutlang < Import::Demandware

  def baseurl; 'https://www.helmutlang.com'; end
  def subdir;  'helmutlang_US'; end
  def product_id_pattern; /\/([^\.\/]+)\.html/; end #F07HM419,default,pd.html
  def brand_name_default; 'Helmut Lang'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'womens-all/all-items,default,sc.html', 'mens-all/mens-all,default,sc.html', 'fragrance/fragrance,default,pg.html',
    ].each do |url_part|
      puts url_part
      url = "#{baseurl}/#{url_part}"
      resp = open(url)
      html = Nokogiri::HTML(resp.read)

      urls = html.css('#search a').map{|a| a.attr('href').sub(/\?.*/, '')}.select{|a| a =~ /[A-Z0-9]+,default,pd\.html$/}
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
    product_id = original_url.match(product_id_pattern)[1].split(',').first

    resp = get_request original_url
    return false if resp.response_code != 200

    url = original_url

    page = resp.body
    html = Nokogiri::HTML(page)

    # in case we have link with upc instead of inner uuid of product
    canonical_url = html.css('link[rel="canonical"]').first.attr('href').sub(/\?.*/, '')

    if canonical_url != url
      url = canonical_url
      product_id = url.match(product_id_pattern)[1].split(',').first
      url = "#{baseurl}#{url}" if url !~ /^http/
    end

    if page.match(/styleID: "([A-Z0-9]+)"/)
      product_id = page.match(/styleID: "([A-Z0-9]+)"/)[1]
    end
    # product_id_param = product_id

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#pdpMain .product-name').first.text.strip
    # category = html.css('#breadcrumb a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
    # color_param = "dwvar_#{product_id_param}_color"
    images = html.css(".productimages img").map{|img| img.attr('src')}
    image_url = images.shift

    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/default/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    data_resp = data_resp.body.strip.gsub(/inStockDate\:\s\"[^"]+\",/, '').gsub(/(['"])?([a-zA-Z0-9_]+)(['"])?:/, '"\2":')
    begin
      data = JSON.parse(data_resp)
    rescue JSON::ParserError => e
      return false
    end

    data['variations']['variants'].each do |v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      color = v['attributes']['color']
      size = v['attributes']['size']

      results << {
        title: product_name,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: image_url,
        style_code: product_id,
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