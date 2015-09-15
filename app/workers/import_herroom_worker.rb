class ImportHerroomWorker

  include Sidekiq::Worker
  sidekiq_options unqiue: true, retry: true

  def perform url
    resp = Curl.get(url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if page =~ /is no longer available/ || html.css('#hdnSizeColors').size == 0

    variants = html.css('#hdnSizeColors').first.attr('value')
    return false if variants.blank?

    product_name = html.css('#product-name h1').text
    style_code = html.css('#hdnStyleNumber').first.attr('value')
    # category = html.css('.crumbtrail a').inject([]){|ar, el| el.text == 'home' ? '' : ar << el.text; ar}.join(' > ')
    category = page.match(/'category' : '([^\']+)'/)[1]

    basic_price = html.css('.itemPrice').text

    images = html.css('.product-thumbs-wrapper a.product-thumbnail').map{|a| a.attr('rel').match(/largeimage:\s?\'([^\']+)\'/)[1]}
    image = images.shift
    brand = page.match(/\'brand\' \: \'([^\']+)'/)[1]
    product_id = page.match(/\'id\' \: \'[^-]+\-(.+)'/)[1]

    data = JSON.parse variants.gsub("'", '"')
    products = Product.where(source: source, source_id: data.map{|row| row['SKU']})
    data.each do |row|
      product = products.select{|product| product.source_id == row['SKU']}.first
      product = Product.new(source: source, source_id: row['SKU']) unless product
      product.attributes = {
        brand: brand,
        title: product_name.sub(/^#{Regexp.quote brand}\s?/i, '').sub(/\s?#{product_id}$/i, ''),
        category: category,
        price: (row['SalePrice'] == '$0.00' ? basic_price : row['SalePrice']).sub('$', ''),
        color: row['ColorName'],
        size: row['Size'],
        style_code: style_code,
        upc: row['SKU'],
        url: url,
        image: image,
        additional_images: images
      }
      product.save if product.changed?
    end

    data.size
  end

  def self.spawn
    rows = CSV.read('tmp/sources/herrom-products-links.csv')
    rows.each do |row|
      self.perform_async "http://www.herroom.com/#{row.first}"
    end
  end

  def source
    'herroom'
  end

end