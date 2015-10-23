class Import::Shopbop < Import::Base

  def self.perform rewrite: false, update_file: true, url: nil
    instance = self.new
    instance.perform rewrite: rewrite, update_file: update_file, url: url
  end

  def get_file update_file=true, url=nil
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

    created_ids = []
    updated_ids = []

    SmarterCSV.process(filename, chunk_size: 5_000) do |rows|
      items = prepare_data rows

      products = Product.where(source: source, source_id: items.map{|r| r[:source_id]}).inject({}){|obj, pr| obj[pr.source_id] = pr; obj}
      to_update = []
      to_create = []

      source_ids = products.keys

      items.each do |r|
        (r[:source_id].in?(source_ids) ? to_update : to_create) << r
      end

      if to_create.size > 0
        keys = to_create.first.keys
        keys += [:match, :created_at, :updated_at]
        tn = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([true, tn, tn]).map{|el| Product.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}
                RETURNING id"
        resp = Product.connection.execute sql
        created_ids.concat resp.map{|r| r['id'].to_i}
      end

      to_update.each do |row|
        product = products[row[:source_id]]
        row.delete :upc if row[:upc].blank?
        product.attributes = row
        product.save if product.changed?

        updated_ids << product.id
      end
    end

    processed_ids = created_ids + updated_ids

    active_ids = Product.shopbop.where(match: true).pluck(:id)
    non_active = active_ids - processed_ids

    Product.shopbop.where(id: non_active).update_all(match: false)
    Product.shopbop.where(id: updated_ids).where(match: false).update_all(match: true)
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

    convert_brand(items)

    items
  end

  def source
    'shopbop'
  end

end