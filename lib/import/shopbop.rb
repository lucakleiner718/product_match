class Import::Shopbop < Import::Platform::Bop

  def default_file; 'http://customfeeds.easyfeed.goldenfeeds.com/1765/custom-feed-sb-ed-shopbop638-amazonpadssbgoogle_usd_with_sku.csv'; end
  def source; 'shopbop'; end

  def perform url=nil, force=false
    filename = get_file(url)
    return false if !@file_updated && !force

    created_ids = []
    updated_ids = []

    process_batch(filename) do |rows|
      items = prepare_data(rows)
      brands += items.map{|item| item[:brand_name]}

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
        row.delete(:upc) if row[:upc].blank?
        product.attributes = row

        if product.price_changed?
          ProcessImportUrlWorker.perform_async(self.class.name, 'update_product_page', product.id)
        end

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

    true
  end

  def self.update_product_page product_id
    product = Product.find(product_id)
    instance = self.new
    instance.update_product_page(product)
  end

  def update_product_page product
    url = product.url
    return false if url !~ /shopbop\.com/

    resp = get_request(url)

    style_code = resp.body.scan(/productPage\.productCode=['"]([^'"]+)['"]/).try(:first).try(:first)
    return false if !style_code || product.style_code != style_code

    list_price = resp.body.scan(/productPage\.listPrice=['"]([^'"]+)['"]/).try(:first).try(:first)
    sale_price = resp.body.scan(/productPage\.sellingPrice=['"]([^'"]+)['"]/).try(:first).try(:first)

    if product.price != list_price
      product.price = list_price
      product.price_sale = nil
    end
    if list_price != sale_price
      product.price_sale = sale_price
    end

    product.save! if product.changed?
  end

  private

  def prepare_data(rows)
    results = []
    rows.each do |r|
      addit_images = [r[:additional_image_link], r[:additional_image_link1], r[:additional_image_link2],
        r[:additional_image_link3], r[:additional_image_link4]].select{|img| img.present? && img != r[:image_link]}
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
        price: r[:price].to_s,
        price_sale: r[:sale_price].to_s,
        color: r[:color],
        size: r[:size],
        upc: (r[:gtin] || r[:ean]),
        material: r[:material],
        gender: r[:gender],
        additional_images: addit_images
      }
    end

    prepare_items(results)

    Brand.where(id: results.map{|r| r[:brand_id]}.uniq, in_use: false).update_all in_use: true

    results
  end
end
