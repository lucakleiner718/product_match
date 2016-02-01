class PopulateActiveProductsWorker
  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform
    ActiveProduct.delete_all

    processed_style_codes = {
      shopbop: [],
      eastdane: []
    }
    products = Product.matching.in_stock#.select('distinct(style_code), *')
    items = []
    products.find_each do |product|
      next if processed_style_codes[product.source.to_sym].include?(product.style_code)
      processed_style_codes[product.source.to_sym] << product.style_code

      ap = ActiveProduct.new
      ap.title = product.title
      ap.brand_id = product.brand_id
      ap.price = product.price_m.to_f
      ap.category = product.category
      ap.source = product.source
      ap.style_code = product.style_code
      ap.image = product.image
      ap.additional_images = product.additional_images
      ap.gender = product.gender
      ap.material = product.material
      ap.google_category = product.google_category
      ap.shopbop_added_at = product.created_at
      ap.url = product.url
      upc = Product.matching.where(style_code: product.style_code).pluck(:upc).compact
      ap.retailers_count = upc.size > 0 ? Product.not_matching.where(upc: upc).select('distinct(style_code), source').group_by{|el| el.source}.size : 0
      # ap.save!

      item = ap.attributes
      item.delete('id')
      items << item
    end

    keys = items.first.keys
    items.in_groups_of(1_000, false) do |part|
      sql = "INSERT INTO active_products
                (#{keys.join(',')})
                VALUES #{part.map{|r| "(#{r.values.map{|el| ActiveProduct.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}"
      ActiveProduct.connection.execute sql
    end
  end
end
