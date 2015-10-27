class Import::Vince < Import::Venda

  def baseurl; 'http://www.vince.com'; end
  def brand_name_default; 'Vince'; end

  def perform
    [
      'women/new-arrivals-women/icat/wnewarrivals',
      'women/pre-order/icat/preorderwps15',
      'women/iconic-essentials/icat/wiconicessentials',
      'women/sweaters/icat/wsweatersall',
      'women/blouses+tops/icat/wblousestops',
      'women/tees+tanks/icat/wmteestanks',
      'women/dresses+jumpsuits/icat/wdressesskirts',
      'view-all/icat/wouterwearjackets',
      'women/skirts/icat/wskirts',
      'view-all/icat/wpantsleggings',
      'women/accessories/icat/waccessoriesall',

      'handbags/view-all/icat/handbags_view_all',

      'shoes/view-all/icat/wshoesall',

      'sale/women-sale/icat/wsaleall',
      'sale/men-sale/icat/msaleall',

      'men/new-arrivals-men/icat/mnewarrivals',
      'men/iconic-essentials/icat/messentials',
      'men/sweaters/icat/msweatersknits',
      'men/sweatshirts+hoodies/icat/msweatshirts',
      'men/shirts/icat/mshirts',
      'men/tees+polos/icat/mteespolos',
      'view-all/icat/mouterwearjackets',
      'view-all/icat/mpantsshorts',
      'men/scarves+hats/icat/maccessories',
      'men/view-all/icat/mfootwearall',

      'girls-7-14/icat/g714newarrivals',
      'girls-2-6x/icat/g46xnewarrivals',
      'kids/baby-girls-6-24m/icat/babygirls',
      'boys-8-16/icat/b816newarrivals',
      'boys-2-7/icat/b47newarrivals',
      'kids/baby-boys-6-24m/icat/babyboys '
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

        products = html.css('.prod-search-results .prod-name a').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0 || (products.size < perpage * 0.9 && products.size == urls.size)

        urls.concat products
        pagenum += 1
      end

      urls = urls.map{|url| build_url(url)}.uniq

      spawn_products_urls urls
    end
  end

  def process_url url
    log "Processing url: #{url}"
    resp = get_request url
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    js = html.css('script:contains("StoreJSON")').first.text
    json_str = "[#{js.scan(/StoreJSON\(({.*})\);/).map{|el| "[#{el.first}]"}.join(',')}]"
    json = JSON.parse(json_str)

    gender = nil
    results = []
    product_name = html.css('#tag-invtname').first.text.strip
    categories = html.css('.crumbtrail a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text.strip; ar}
    if categories[0] == 'Women'
      gender = 'Female'
      categories.shift
    end
    category = categories.join(' > ')

    image_url_mask = "#{baseurl}/content/ebiz/vince/invt/{{style_code}}/{{style_code}}{{color}}setmedium.jpg"
    colors_images = page.scan(/Venda\.Attributes\.SwatchURL\["([A-Za-z\s\-]+)"\]\s=\s"http:\/\/www\.vince\.com\/content\/ebiz\/vince\/invt\/[a-z0-9]+\/[a-z0-9]+(.*)setswatch\.jpg";/)
    colors_images = colors_images.inject({}){|obj, el| obj[el[0]] = el[1]; obj}

    json.each do |row|
      options = row[1]
      price = options['atrsell']
      upc = options['atrsku']
      color = options['atr1']
      size = options['atr2']
      style_code = options['atrdssku']

      image = page.scan(/#{image_url_mask.gsub('{{style_code}}', style_code).sub('{{color}}', colors_images[color])}/).first
      # page.scan(/#{image_url_mask.gsub('{{style_code}}', style_code).sub('{{color}}', '([^_]+)')}/)
      # binding.pry unless image
      raise "No image" unless image

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
        gender: gender
      }
    end

    process_results results
  end

end