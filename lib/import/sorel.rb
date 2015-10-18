class Import::Sorel < Import::Demandware

  def baseurl; 'http://www.sorel.com'; end
  def subdir; 'Sorel_US'; end
  def lang; 'en_US'; end
  def product_id_pattern; /-([A-Z0-9]+)\.html/; end
  def brand_name_default; 'Sorel'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    [
      'womens-boots-shoe', 'mens-boots-outdoor-shoes', 'kids-boots-outdoor-shoes', 'apparel-jackets-hats',
      'sale-boots-slippers-shoes'
    ].each do |url_part|
      puts url_part
      size = 60
      urls = []
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

    canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    if canonical_url != url
      product_id = canonical_url.match(product_id_pattern)[1]
    end

    product_id_param = product_id

    # brand_name = page.match(/"brand":\s"([^"]+)"/)[1]
    brand_name = brand_name_default# if brand_name.downcase == 'n/a'

    results = []

    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip

    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text.downcase.in?(['home', 'Return to search results'.downcase]) ? '' : ar << el.text.strip; ar}.join(' > ')

    color_param = "dwvar_#{product_id_param}_color"

    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/#{lang}/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    data = JSON.parse(data_resp.body.strip)

    images = html.css('.thumbnail-link').map{|img| img.attr('href')}#.sub(/\/#{product_id}_\d{1,3}_m/)}
    if images.size == 0
      ppi = html.css('.product-primary-image').first
      if ppi
        if ppi.css('a').size > 0
          images = [html.css('.product-primary-image a').first.attr('href')]
        else
          images = [html.css('.product-primary-image').first.attr('data-defaultasset')]
        end
      end
    end
    # http://s7d5.scene7.com/is/image/ColumbiaSportswear2/1554681_010_m
    image = images.shift
    default_color_id = image.match(/\/#{product_id}_([^\_]+)_/)[1] if image

    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color = v['attributes']['variationColor'].strip
      size = v['attributes']['variationSize']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['variationColor']
      color_url = "#{url}?#{color_param}=#{color_id}"

      image_url = nil
      image_url = image.sub(/\/#{product_id}_#{default_color_id}_/, "/#{product_id}_#{color_id}_") if image

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