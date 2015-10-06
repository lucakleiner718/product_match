class Import::Shopbop < Import::Base

  def self.perform rewrite: false, update_file: false, url: nil
    instance = self.new
    instance.perform rewrite: rewrite, update_file: update_file, url: url
  end

  def get_file update_file=false, url=nil
    filename = "tmp/sources/shopbop.csv"

    url ||= 'http://customfeeds.easyfeed.goldenfeeds.com/1765/custom-feed-sb-ed-shopbop638-amazonpadssbgoogle_usd_with_sku.csv'

    if !File.exists?(filename) || (update_file && File.mtime(filename) < 12.hours.ago)
      body = Curl.get(url).body
      body.force_encoding('UTF-8')
      File.write filename, body
    end

    filename
  end

  def perform rewrite: false, update_file: false, url: nil
    if rewrite
      Product.where(source: source).delete_all
    end

    filename = get_file update_file, url

    SmarterCSV.process(filename, chunk_size: 1_000) do |rows|
      items = prepare_data rows

      products = Product.where(source: source, source_id: items.map{|r| r[:source_id]})
      to_update = []
      to_create = []

      items.each do |r|
        (r[:source_id].in?(products.map(&:source_id)) ? to_update : to_create) << r
      end

      if to_create.size > 0
        keys = to_create.first.keys
        keys += [:created_at, :updated_at]
        tn = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([tn, tn]).map{|el| Product.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}"
        Product.connection.execute sql
      end

      to_update.each do |row|
        product = products.select{|pr| pr.source_id == row[:source_id]}.first
        product.attributes = row
        product.save if product.changed?
      end
    end
  end

  def prepare_data rows
    items = []
    rows.each do |r|
      items << {
        source: source,
        source_id: r[:id],
        style_code: r[:item_group_id],
        brand: normalize_brand(r[:brand]),
        title: normalize_title(r[:title], r[:brand]),
        category: r[:product_type],
        google_category: r[:google_product_category],
        url: r[:link],
        image: r[:image_link],
        price: r[:price],
        price_sale: (r[:sale_price].present? ? r[:sale_price] : nil),
        color: r[:color],
        size: r[:size],
        upc: r[:gtin],
        material: r[:material],
        gender: r[:gender],
        additional_images: [r[:additional_image_link], r[:additional_image_link1], r[:additional_image_link2], r[:additional_image_link3], r[:additional_image_link4]].select{|img| img.present?}
      }
    end
    items
  end

  def source
    'shopbop'
  end

end