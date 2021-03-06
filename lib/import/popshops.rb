class Import::Popshops < Import::Base

  def source; 'popshops'; end

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
    33184 => 'Unisex Watches',
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

  def self.perform(brand: nil, merchant: nil, category_id: nil)
    self.new.perform(brand: brand, merchant: merchant, category_id: category_id)
  end

  def perform(brand: nil, merchant: nil, category_id: nil)
    base_url_params = {category: category_id}
    if brand
      base_url_params[:brand] = brand
    elsif merchant
      base_url_params[:merchant] = merchant
    elsif
      raise
    end

    page = 1
    while page <= 100 do
      url = build_url_params(base_url_params.merge({page: page}))
      log(url)

      resp = get_request(url)
      body = resp.body
      @xml = Nokogiri::XML(body)

      products = @xml.search('results products product')
      @categories = @xml.search('categories category').map{|c| [c.attr('id'), c.attr('name')]}.inject({}){|obj, el| obj[el[0]] = el[1]; obj}
      @merchants = @xml.search('merchants merchant').map{|m| [m.attr('id'), m.attr('name')]}.inject({}){|obj, el| obj[el[0]] = el[1]; obj}

      break if products.size == 0 || products.size < 90

      items = prepare_data(products)

      @exists_products = Product.where(source: source, source_id: items.map{|r| r[:source_id]}).each_with_object({}){|el, obj| obj[el.source_id] = el}
      to_update = []
      to_create = []

      items.each do |r|
        (r[:source_id].in?(@exists_products.keys) ? to_update : to_create) << r
      end

      process_to_create(to_create)
      process_to_update(to_update)

      page += 1
    end

    true
  end

  def process_to_create(to_create)
    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:created_at, :updated_at]
      tn = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([tn, tn]).map{|el| Product.sanitize el}.join(',')})"}.join(',')}"
      Product.connection.execute sql
    end
  end

  def process_to_update(to_update)
    to_update.each do |row|
      product = @exists_products[row[:source_id]]

      %i|upc size color price price_sale url image sku retailer price_currency|.each do |column|
        row.delete(column) if row[column].blank?
      end

      product.attributes = row
      product.save! if product.changed?
    end
  end

  def prepare_data(products)
    results = []
    brands = @xml.search('resources brands brand').inject({}){|obj, el| obj[el.attr('id')] = normalize_brand(el.attr('name')); obj}
    products.each do |r|
      brand = brands[r.attr('brand')]
      item = {
        source: source,
        source_id: r.attr('id'),
        brand: brand,
        title: r.attr('name'),
        image: r.attr('image_url_large'),
        upc: nil,
        mpn: nil,
        url: nil,
        price: nil,
        size: nil,
        color: nil,
        sku: nil,
        category: nil,
        description: r.attr('description'),
        retailer: nil,
        price_currency: nil
      }

      if r.attr('category')
        item[:category] = @categories[r.attr('category')] || CATEGORIES[r.attr('category').to_i]
      end

      item[:size] = item[:description].match(/Size: ([^\.\,]+)(\.|,)/)[1] rescue nil
      item[:color] = item[:description].match(/Color: ([^\.\,]+)(\.|,)/)[1] rescue nil

      r.search('attributes attribute').each do |attribute|
        attr_name = attribute.attr('name')
        if attr_name.in?(['upc', 'mpn', 'ean'])
          item[attr_name.to_sym] = attribute.attr('value') if attribute.attr('value').present?
        end
      end

      offer = r.search('offers offer').first
      if offer
        item[:url] = offer.attr('url')
        item[:price] = offer.attr('price_retail')
        item[:size] ||= offer.attr('description').match(/Size: ([^\.\,]+)(\.|,)/)[1] rescue nil
        item[:color] ||= offer.attr('description').match(/Color: ([^\.\,]+)(\.|,)/)[1] rescue nil
        item[:sku] ||= offer.attr('sku')
        item[:retailer] = @merchants[offer.attr('merchant')] if offer.attr('merchant')
        item[:price_currency] = offer.attr('currency_iso')
      end

      if item[:upc].blank?
        if item[:ean].present? && GTIN.new(item[:ean]).valid?
          item[:upc] = item[:ean]
        elsif item[:sku].present? && GTIN.new(item[:sku]).valid?
          item[:upc] = item[:sku]
        elsif item[:mpn].present? && GTIN.new(item[:mpn]).valid?
          item[:upc] = item[:mpn]
        end
      end

      if item[:size].blank? && item[:color].blank? && item[:sku] && item[:mpn] && item[:sku].gsub('_', ' ') == item[:mpn] && item[:brand] == 'Joie'
        mpn = item[:mpn].split(' ')
        item[:size] = mpn[2]
        item[:color] = mpn[1]
      end

      if item[:price].blank?
        price_max = r.attr('price_max').to_f
        price_min = r.attr('price_min').to_f
        if price_max > 0 && price_min > 0
          item[:price] = (price_max + price_min) / 2
        elsif price_max > 0
          item[:price] = price_max
        elsif price_min > 0
          item[:price] = price_min
        end
      end

      results << item
    end

    prepare_items(results)
    results
  end

  def build_url_params(params = {})
    url_params = {}.merge(URL[:params]).merge(params)
    "#{URL[:base]}?#{url_params.map{|k,v| "#{k}=#{v}"}.join('&')}"
  end

  def self.get_info(brand_id)
    url = self.new.build_url_params(brand: brand_id, count: 1)

    resp = get_request(url)
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
