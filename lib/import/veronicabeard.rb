class Import::Veronicabeard < Import::Base

  # platform = unknown3

  def baseurl; 'https://www.veronicabeard.com'; end
  def brand_name; 'Veronica Beard'; end

  def perform
    start = 0
    rows_amount = 15
    while true
      url_part = "search/?wt=json&start=#{start}&rows=#{rows_amount}&sort=cat_product_sequence_7_i+asc&q=attr_cat_id%3A7"
      log url_part

      json_str = get_request(url_part).body
      json = JSON.parse(json_str)
      rows = json['response']['docs']

      break if rows.size == 0
      start += rows_amount

      rows.each do |row|
        process_row row
      end
    end
  end

  def process_row row
    image_prefix = "https://s3.amazonaws.com/veronicabeard-java/images/skus/"

    product_name = row['product_name_t']
    url = build_url row['page_name_s']

    images = row.select{|k, v| k =~ /^image_/ && v !~ /SWATCH/}
    images = images.inject({}) do |obj, (k, img)|
      color = k.scan(/^image_([^_]+)_/)[0][0]
      obj[color] ||= []
      obj[color] << "#{image_prefix}#{img}"
      obj
    end

    price = row['max_price_i']
    price_sale = row['min_price_i']

    results = []
    row['attr_product_sku_info'].each do |attr|
      items = attr.split('|')

      item_price = items[5] || price
      item_price = item_price.to_f / 100 if item_price.present?
      item_price_sale = price_sale.to_f / 100 if price_sale.present?

      color = items[2]

      item_images = [] + (images[color] || [])
      item_main_image = item_images.shift

      results << {
        title: product_name,
        brand: brand_name,
        # category: category,
        price: item_price,
        price_sale: item_price_sale,
        color: color,
        size: items[3],
        upc: items[1],
        url: url,
        image: item_main_image,
        additional_images: item_images,
        style_code: items[6],
        gender: "Female",
        source_id: items[0]
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end
end
