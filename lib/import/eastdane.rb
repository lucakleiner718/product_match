class Import::Eastdane < Import::Platform::Bop

  def default_file; 'http://customfeeds.easyfeed.goldenfeeds.com/1765/custom-feed-sb-ed-eastdan474-amazonpadsedgoogle_usd_no_sku_upc.csv'; end
  def csv_col_sep; "\t"; end
  def source; 'eastdane'; end

  def perform url, force=false
    url ||= default_file
    filename = get_file(url)
    return false if !@file_updated && !force

    created_ids = []
    updated_ids = []

    process_batch(filename) do |rows|
      items = prepare_data rows

      products = Product.where(source: source, source_id: items.map{|r| r[:source_id]}).inject({}){|obj, pr| obj[pr.source_id] = pr; obj}
      to_update = []
      to_create = []

      source_ids = products.keys

      items.each do |r|
        (r[:source_id].in?(source_ids) ? to_update : to_create) << r
      end

      created_ids += process_create(to_create)

      to_update.each do |row|
        product = products[row[:source_id]]
        row.delete :upc if row[:upc].blank?
        product.attributes = row
        product.save! if product.changed?

        updated_ids << product.id
      end
    end

    processed_ids = created_ids + updated_ids

    active_ids = Product.where(source: source).where(match: true).pluck(:id)
    non_active = active_ids - processed_ids
    Product.where(source: source).where(id: non_active).update_all(match: false)
    Product.where(source: source).where(id: updated_ids).where(match: false).update_all(match: true)

    in_store_ids = Product.where(source: source).where(in_store: true).pluck(:id)
    Product.where(source: source).where(id: in_store_ids - processed_ids).update_all(in_store: false)
    Product.where(source: source).where(id: processed_ids).update_all(in_store: true)

    if @file_updated
      replace_original_tmp_file(filename, url)
    end

    true
  end

  def prepare_data rows
    results = []
    rows.each do |r|
      results << {
        source: source,
        source_id: r[:id],
        style_code: r[:item_group_id],
        brand: r[:brand],
        title: r[:title],
        category: r[:product_type],
        google_category: r[:google_product_category],
        url: r[:link],
        image: r[:image_link],
        price: r[:price],
        price_sale: r[:sale_price],
        color: r[:color],
        size: r[:size],
        upc: (r[:upc] || r[:ean]),
        material: r[:material],
        gender: r[:gender],
        additional_images: [r[:additional_image_link], r[:additional_image_link1], r[:additional_image_link2], r[:additional_image_link3], r[:additional_image_link4]]
      }
    end

    prepare_items(results)

    Brand.where(id: results.map{|r| r[:brand_id]}.uniq, in_use: false, disabled: false).update_all(in_use: true)

    results
  end
end
