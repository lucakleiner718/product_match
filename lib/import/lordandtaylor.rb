class Import::Lordandtaylor < Import::Base

  def baseurl; 'http://www.lordandtaylor.com'; end

  def perform
    resp = get_request("#{baseurl}/webapp/wcs/stores/servlet/en/lord-and-taylor/HBCBrandsListView?storeId=10151&catalogId=10102&langId=-1")
    html = Nokogiri::HTML(resp.body)

    brands_links = html.css(".byword a").map{|link| link.attr('href')}
    brands_links.each do |url_part|
      log url_part
      urls = []

      if url_part =~ /HBCCoachLandingView/
        brand_page = get_request(url_part).body
        brand_page_html = Nokogiri::HTML(brand_page)
        brand_categories_links = brand_page_html.css('.ad table tr:last a').map{|a| a.attr('href')}
        brand_categories_links.each do |brand_categories_link|
          cat_page = get_request(brand_categories_link).body
          cat_html = Nokogiri::HTML(cat_page)
          products = cat_html.css('.product .product_photo a').map{|a| a.attr('href')}
          urls.concat products
        end
      else
        brand_page = get_request(url_part).body
        brand_page_html = Nokogiri::HTML(brand_page)
        products = brand_page_html.css('#totproductsList > li .catEntryDisplayUrlScript:first').map{|l| l.text.match(/setCatEntryDisplayURL\("([^"]+)"\)/)[1]}
        urls.concat products

        pagination_links = brand_page_html.css('#list_page1 li a')
        pagination_links.shift #removed first active link on pagination
        pagination_links.pop #removed next link on pagination
        pagination_links.each do |pagination_link|
          pagination_url = pagination_link.attr('onclick').match(/goToResultPage\('([^']+)'/)[1]
          brand_page = get_request(pagination_url).body
          brand_page_html = Nokogiri::HTML(brand_page)
          products = brand_page_html.css('#totproductsList > li .catEntryDisplayUrlScript:first').map{|l| l.text.match(/setCatEntryDisplayURL\("([^"]+)"\)/)[1]}
          urls.concat products
        end
      end

      spawn_products_urls urls
    end
  end

  def process_url original_url
    log "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    return false if html.css('#ItemAddError_div_7').size == 1

    results = []

    title = page.match(/br_data\.prod_name = '([^']+)';/) && $1
    title = html.css('title').first.text.split('|').first.strip unless title

    brand = page.match(/"brand":\s"([^"]+)"/) && $1
    brand = page.match(/manufacturer\s([^<]+)\s<br/) && $1 unless brand
    brand = html.css('.tit').first.try(:text) unless brand
    raise "No brand" unless brand

    style_code = page.match(/br_data\.prod_id = '([a-z0-9\-]+)';/i) && $1
    style_code = html.css('.webid p:first').text unless style_code

    html.css('div[id^="entitledItem_"]').each_with_index do |entitledItem, index|
      json_str = entitledItem.text.gsub(/,\s+}/, "}").gsub(/,\s+\]/, "]") # remove trailing comma
      json = JSON.parse(json_str)

      default_image = json.select{|r| r['ItemImage'].present?}.first
      default_image = default_image['ItemImage'] if default_image

      collection = html.css('#LitTabshow1').size == 1

      json.each do |row|
        attrs = row['Attributes'].keys
        size = attrs.select{|el| el =~ /Size/}.first
        size = size.sub('Size_', '') if size
        color = attrs.select{|el| el =~ /VendorColor_/}.first
        color = color.sub('VendorColor_', '') if color
        image = row['ItemImage'] || default_image
        price = row['listPrice'].sub(/^\$/, '')
        price_sale = row['offerPrice'].sub(/^\$/, '')
        upc = row['ItemThumbUPC']
        source_id = row['catentry_id']

        if collection
          list_item = html.css('#LitTabshow1 .listitems_cont')[index]
          title = list_item.css('h2').first.text
          style_code = list_item.css('.listitem_descri span').first.text.match(/: : (.*)/)[1].strip
        end

        next unless brand

        results << {
          source_id: source_id,
          title: title,
          brand: brand,
          price: price,
          price_sale: price_sale,
          upc: upc,
          url: original_url,
          style_code: style_code,
          image: image,
          color: color,
          size: size,
        }
      end
    end

    process_results results
  end

  def process_results results
    convert_brand(results)

    results.each do |row|
      if row[:source_id]
        product = Product.where(source: source, source_id: row[:source_id]).first_or_initialize
      else
        product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      end
      product.attributes = row
      product.save
    end
  end

end