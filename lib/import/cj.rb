class Import::Cj < Import::Base

  include Import::FileImport

  def default_file; 'http://upc.socialrootdata.com/downloads/feeds/cj/SouthBeachSwimsuits-SouthBeachSwimSuits_com.csv'; end
  def source; 'cj.com'; end
  def csv_col_sep; "\t"; end

  def self.perform(url=nil, force=false)
    self.new.perform(url, force)
  end

  def perform(url=nil, force=false)
    url ||= default_file
    filename = get_file(url)
    return false if !@file_updated && !force

    csv_rows = CSV.read(filename, col_sep: csv_col_sep, headers: true, header_converters: :symbol)

    results = build_results(csv_rows)
    prepare_items(results)
    process_results_batch(results)

    if @file_updated
      replace_original_tmp_file(filename, url)
    end

    true
  end

  def build_results(rows)
    results = []
    rows.each do |r|
      sku = r[:sku] || r[:manufacturerid]
      next if sku.in?(['#REF!', '#NAME?'])

      brand = r[:manufacturer]
      next unless brand

      upc = r[:upc]
      next if upc.blank? || !GTIN.new(upc).valid?

      style_code = nil
      # style_code = r[:name].match(/([a-z0-9\-\/]+)$/i) && $1
      # # next unless style_code
      #
      color, size = nil
      # if style_code && sku =~ /^#{style_code}/
      #   color, size = sku.sub(/^#{style_code}-/, '').split('-', 2)
      # end

      gender = nil
      gender = r[:author].capitalize if r[:author].in?(%w(female male))

      results << {
        retailer: r[:programname],
        source: source,
        source_id: sku,
        style_code: style_code,
        brand: brand,
        title: r[:name],
        description: r[:description],
        url: r[:buyurl],
        price: r[:price],
        price_sale: r[:saleprice],
        price_currency: r[:currency],
        upc: r[:upc],
        image: r[:imageurl],
        color: (color ? color.sub(/_+$/, '') : nil),
        size: size,
        category: r[:advertisercategory],
        gender: gender
      }
    end

    # results.group_by{|row| row[:style_code]}.each do |style_code, rows|
    #   rows_with_size = rows.select{|r| r[:size].present?}
    #
    #   next if rows_with_size.size < 2
    #
    #   string = find_same_string(rows_with_size.map{|row| row[:size]})
    #
    #   if string
    #     rows_with_size.each do |row|
    #       row[:size].sub!(/^#{Regexp.quote string}/i, '')
    #     end
    #   end
    # end

    # results.each do |row|
    #   next unless row[:size].present?
    #
    #   row[:size] = row[:size].gsub(/_+/, '-').gsub(/-+$/, '')
    # end

    results
  end

  private

  def find_same_string(strings)
    last_eq_str = nil
    (1..100).each do |index|
      search_string = strings[0][0, index]

      eq = strings.map do |str|
        str[0, index] == search_string
      end.all?

      if eq
        last_eq_str = search_string
      else
        break
      end
    end
    last_eq_str
  end
end
