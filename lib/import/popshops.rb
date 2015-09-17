class Import::Popshops < Import::Base

  BRANDS = {
    51539 => 'Current/Elliott',
    29555 => 'Eberjey',
    25282 => 'Joie',
    172832 => 'Honeydew Intimates',
    706936 => 'Michael Kors',
    85340 => 'Kate Spade',
    75499 => 'Tory Burch',
    710349 => 'Michele Watches',
    1916908 => 'Kate Spade Watches',
    54558 => 'Michele'
  }

  CATEGORIES = {
    3000 => 'Clothing & Accessories',
    3300 => "Women's Clothing",
    3315 => "Women's Pants & Jeans",
    4400 => 'Jewelry & Watches',
    4425 => 'Watches',
    4430 => "Men's Watches",
    4435 => "Women's Watches",
    4445 => 'Watch Parts & Accessories',
    4480 => 'Jewelry',
    4540 => 'Bracelets',
    11000 => 'Miscellaneous',
    33184 => 'Unisex Watches"',
  }

  URL = {
    base: 'http://www.popshops.com/v3/products.xml',
    params: {
      account: '1wgmmtk04u194dbc04ojiurit',
      catalog: '2q7zdruy44960cbzsecpaqf3t',
      results_per_page: 100,
      include_identifiers: true
    }
  }

  def self.perform brand_id: nil, rewrite: false, category_id: nil
    instance = self.new
    instance.perform brand_id: brand_id, rewrite: rewrite, category_id: category_id
  end

  def perform brand_id: nil, rewrite: false, category_id: nil
    raise unless brand_id

    brand = BRANDS[brand_id]
    if rewrite
      Product.where(source: source, brand: brand).delete_all
    end

    page = 1
    while true do
      url = build_url(brand: brand_id, category: category_id, page: page)

      resp = Curl.get(url)
      body = resp.body
      @xml = Nokogiri::XML(body)

      products = @xml.search('results products product')
      @categories = @xml.search('categories category').map{|c| [c.attr('id'), c.attr('name')]}.inject({}){|obj, el| obj[el[0]] = el[1]; obj}

      break if products.size == 0

      items = prepare_data products

      @exists_products = Product.where(source: source, source_id: items.map{|r| r[:source_id]})
      to_update = []
      to_create = []

      items.each do |r|
        (r[:source_id].in?(@exists_products.map(&:source_id)) ? to_update : to_create) << r
      end

      process_to_create to_create
      process_to_update to_update

      page += 1
    end
  end

  def process_to_create to_create
    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:created_at, :updated_at]
      tn = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([tn, tn]).map{|el| Product.sanitize el}.join(',')})"}.join(',')}"
      Product.connection.execute sql
    end
  end

  def process_to_update to_update
    to_update.each do |row|
      product = @exists_products.select{|pr| pr.source_id == row[:source_id]}.first
      product.attributes = row
      product.save if product.changed?
    end
  end

  def prepare_data products
    items = []
    products.each do |r|
      brand = @xml.search('resources brands brand[id="'+r.attr('brand')+'"]').first.attr('name')
      item = {
        source: source,
        source_id: r.attr('id'),
        brand: normalize_brand(brand),
        title: normalize_title(r.attr('name'), brand),
        image: r.attr('image_url_large'),
        upc: nil,
        mpn: nil,
        ean: nil,
        url: nil,
        price: nil,
        size: nil,
        color: nil,
        sku: nil,
        category: nil,
        description: r.attr('description')
      }

      if r.attr('category')
        item[:category] = @categories[r.attr('category')] || CATEGORIES[r.attr('category').to_i]
      end

      item[:size] = item[:description].match(/Size: ([^\.\,]+)(\.|,)/)[1] rescue nil
      item[:color] = item[:description].match(/Color: ([^\.\,]+)(\.|,)/)[1] rescue nil

      r.search('attributes attribute').each do |attribute|
        attr_name = attribute.attr('name')
        if attr_name.in?(['upc', 'mpn', 'ean'])
          item[attr_name.to_sym] = attribute.attr('value')
        end
      end

      offer = r.search('offers offer').first
      if offer
        item[:url] = offer.attr('url')
        item[:price] = offer.attr('price_retail')
        item[:size] ||= offer.attr('description').match(/Size: ([^\.\,]+)(\.|,)/)[1] rescue nil
        item[:color] ||= offer.attr('description').match(/Color: ([^\.\,]+)(\.|,)/)[1] rescue nil
        item[:sku] ||= offer.attr('sku')
      end

      if item[:size].blank? && item[:color].blank? && item[:sku] && item[:mpn] && item[:sku].gsub('_', ' ') == item[:mpn] && item[:brand] == 'Joie'
        mpn = item[:mpn].split(' ')
        item[:size] = mpn[2]
        item[:color] = mpn[1]
      end

      items << item
    end
    items
  end

  def source
    'popshops'
  end

  def build_url params = {}
    url_params = {}.merge(URL[:params]).merge(params)
    "#{URL[:base]}?#{url_params.map{|k,v| "#{k}=#{v}"}.join('&')}"
  end

  def self.get_info brand_id
    url = self.new.build_url(brand: brand_id, count: 1)

    resp = Curl.get(url)
    body = resp.body
    xml = Nokogiri::XML(body)

    brand_tag = xml.search('resources brands brand[id="'+brand_id+'"]').first
    brand_name = brand_tag ? brand_tag.attr('name') : nil

    products_tag = xml.search('results products').first
    count = products_tag ? products_tag.attr('count').to_i : 0

    {
      name: brand_name,
      count: count
    }
  end

end