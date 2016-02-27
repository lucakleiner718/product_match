class Import::Temperleylondon < Import::Base

  include Import::FileImport

  def default_file; 'https://www.temperleylondon.com/shop/media/feeds/google_base_default.txt'; end
  def source; 'temperleylondon'; end
  def csv_col_sep; "\t"; end

  def perform(url=default_file, force=false)
    filename = get_file(url)
    return false if !@file_updated && !force

    csv_rows = CSV.read(filename, col_sep: csv_col_sep, headers: true, header_converters: :symbol)

    results = build_results(csv_rows)
    prepare_items(results)
    process_results_batch(results)

    if @file_updated
      replace_original_tmp_file(filename)
    end

    true
  end

  def build_results(rows)
    results = []
    rows.each do |r|
      price, currency = r[:price].split(' ', 2)

      results << {
        source: source,
        source_id: r[:id],
        style_code: r[:item_group_id],
        brand: r[:brand],
        title: r[:title],
        description: r[:description],
        category: r[:product_type],
        google_category: r[:google_product_category],
        url: r[:link],
        image: r[:image_link],
        price: price,
        price_currency: currency,
        # price_sale: r[:sale_price],
        color: r[:color],
        size: r[:size],
        upc: (r[:gtin] || r[:upc] || r[:ean]),
        material: r[:material],
        gender: r[:gender],
        additional_images: r[:additional_image_link].split(',')
      }
    end

    results
  end
end
