class Import::Herroom < Import::Base

  def self.perform rewrite: false
    instance = self.new
    instance.perform rewrite: rewrite
  end

  def perform rewrite: rewrite()
    if rewrite
      Product.where(source: source).delete_all
    end

    filename = 'tmp/sources/_herroom-letters-all.csv'

    return false unless File.exists? filename

    SmarterCSV.process(filename, chunk_size: csv_chunk_size) do |rows|
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
      images = r[:images].split(',')
      image = r[:images].shift

      items << {
        title: normalize_title(r[:product_name], r[:brand]),
        source: source,
        category: r[:category],
        price: r[:price].sub(/^\$/, ''),
        color: r[:color_name],
        size: r[:size_name],
        style_code: r[:style],
        upc: r[:upc],
        url: r[:original_url],
        brand: normalize_brand(r[:brand]),
        source_id: r[:id],
        image: image,
        additional_images: images,
      }
    end
    items
  end

end