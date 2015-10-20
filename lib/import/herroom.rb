class Import::Herroom < Import::Base

  def baseurl; 'http://www.herroom.com'; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def perform
    resp = get_request("#{baseurl}/brands.aspx")
    html = Nokogiri::HTML(resp.body)

    brands_links = html.css(".brands a").map{|link| link.attr('href')}

    brands_links.each do |url_part|
      Rails.logger.debug url_part
      urls = []

      brand_page = get_request("#{baseurl}#{url_part}").body
      brand_page_html = Nokogiri::HTML(brand_page)
      urls.concat brand_page_html.css('table tr td.borderz .img-holder a').map{|l| l.attr('href')}

      pagination_links = brand_page_html.css('.page_nav .pagingsq a').map{|l| l.attr('href')}
      pagination_links.each do |pagination_link|
        brand_page = get_request("#{baseurl}/#{pagination_link}").body
        brand_page_html = Nokogiri::HTML(brand_page)
        urls.concat brand_page_html.css('table tr td.borderz .img-holder a').map{|l| l.attr('href')}
      end

      urls = urls.uniq.map{|u| "#{baseurl}/#{u}"}

      urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
      Rails.logger.debug "spawned #{urls.size} urls #{url_part}"
    end

  end

  def process_url original_url
    # binding.pry
    puts "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    product_name = html.css('#product-name h1').text
    style_code = html.css('#hdnStyleNumber').first.attr('value')
    category = html.css('.crumbtrail a').inject([]){|ar, el| el.text == 'home' ? '' : ar << el.text; ar}.join(' > ')
    price = html.css('.itemPrice').text
    brand = page.match(/'brand'\s?:\s?'([^']+)'/)[1]
    images = html.css('.product-thumbs-wrapper a.product-thumbnail').map{|a| a.attr('rel').match(/largeimage:\s?\'([^\']+)\'/)[1]}
    id = page.match(/\'id\' \: \'[^-]+\-(.+)'/)[1]

    main_image = html.css('.product-main-image').first.attr('src')
    main_image_base = main_image.match(/\/([^\/]+)-[^-]+\./)[1]
    main_image_location = main_image.match(/^(.+)#{main_image_base}/)[1].sub('/items/', '/color-glams/')
    image_pattern = "#{main_image_location}#{main_image_base}-acsx-{{color}}.jpg"

    variants = html.css('#hdnSizeColors').first.attr('value')
    return false if variants.blank?

    data = JSON.parse variants.gsub("'", '"')
    data.each do |row|
      title = normalize_title(product_name.sub(/^#{Regexp.quote brand}\s?/i, '').sub(/\s?#{id}$/i, ''), brand)
      results << {
        title: title,
        brand: brand,
        category: category,
        price: (row['SalePrice'] == '$0.00' ? price : row['SalePrice']),
        color: row['ColorName'],
        size: row['Size'],
        upc: row['SKU'],
        url: original_url,
        image: image_pattern.sub('{{color}}', row['ColorCode'].downcase),
        additional_images: images,
        style_code: style_code,
        gender: 'Female'
      }
    end

    results = convert_brand(results)

    results.each do |row|
      product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.save
    end

  end

end