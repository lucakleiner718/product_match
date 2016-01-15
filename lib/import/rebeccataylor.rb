class Import::Rebeccataylor < Import::Platform::Venda

  # platform = venda

  def baseurl; 'http://www.rebeccataylor.com'; end
  def brand_name_default; 'Rebecca Taylor'; end

  def perform
    [
      'shop/new-arrivals/icat/rtlatestitems', 'shop/dresses-and-jumpsuits/icat/rtdressesandjumpsuits',
      'shop/blouses/icat/rtblouses', 'shop/tops-and-tees/icat/rttopsandtees', 'shop/jackets-coats-and-outerwear/icat/rtjackets',
      'shop/sweaters/icat/rtsweaters', 'shop/pants-shorts-and-skirts/icat/rtbottoms', 'shop/accessories-/icat/rtaccessories',
      'shop/jewelry/icat/rtjewelry', 'shop/shoes/icat/rtshoes', 'shop/sale/icat/rtsale', 'shop/exclusives/icat/rtfeaturedstyles5',
      'shop/rebeccas-favorites/icat/rtfeatured12', 'shop/weekend-essentials/icat/rtfeaturedstyles6',
      'shop/wear-to-work/icat/rtfeaturedstyles1', 'shop/event-dressing/icat/rtfeaturedstyles4',
    ].each do |url_part|
      log url_part
      perpage = 20
      pagenum = 1
      urls = []
      while true
        url = "#{baseurl}/#{url_part}?setpagenum=#{pagenum}&perpage=#{perpage}&layout=noheaders"
        resp = get_request(url)
        next if resp.response_code > 200
        html = Nokogiri::HTML(resp.body)

        products = html.css('#searchResults .prods li .image a').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0 || (products.size < perpage * 0.9 && products.size == urls.size)

        urls.concat products
        pagenum += 1
      end

      spawn_products_urls(urls)
    end
  end

  def process_product(url)
    log "Processing url: #{url}"
    resp = get_request url
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    js = html.css('script:contains("product.setAttributeData({")').first.text
    json_str = "[#{js.scan(/product\.setAttributeData\(({.*})\);/).map{|el| "[#{el.first}]"}.join(',')}]"
    json = JSON.parse(json_str)

    results = []
    product_name = html.css('#productdetail-right h1').first.text.strip
    category = html.css('#breadcrumbs a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}.join(' > ')
    gender = 'Female'

    style_code = json[0][1]['atrdssku']

    image_url_mask = "#{baseurl}/content/ebiz/rt/invt/{{style_code}}/{{style_code}}{{color}}setlarge.jpg"
    colors_images = page.scan(/\.loadImage\("([^"]+)",{\s+setswatch:\s"[^"]+\/#{style_code}(.*)setswatch(_[a-z0-9]+)?\.jpg"/).inject({}){|obj, el| obj[el[0]] = el[1]; obj}

    json.each do |row|
      options = row[1]
      price = options['atrsell']
      upc = options['atrsku']
      color = options['atr1']
      size = options['atr2']

      next unless colors_images[color]

      image = image_url_mask.gsub('{{style_code}}', style_code).sub('{{color}}', colors_images[color])

      results << {
        title: product_name,
        category: category,
        price: price,
        color: color,
        size: size,
        upc: upc,
        url: url,
        image: image,
        style_code: style_code,
        gender: gender,
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
