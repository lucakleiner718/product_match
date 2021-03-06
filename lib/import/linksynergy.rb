require 'net/ftp'

class Import::Linksynergy < Import::Base

  def source; 'linksynergy'; end

  RETAILERS = {
    1237 => 'Nordstrom',
    13867 => 'Bloomingdales',
    24285 => 'Yoox',
    24449 => 'Net A Porter',
    25003 => 'Neiman Marcus',
    35300 => 'Bergdoorfs',
    36623 => 'J Brand',
    37928 => 'The Corner',
    39917 => 'Nasty Gal',
    39655 => 'Sugnlass Hut',
  }

  def self.perform(mid: 1237, rewrite: false, update: true, daily: nil, product_source: nil)
    self.new(mid: mid, rewrite: rewrite, update: update, daily: daily,
      product_source: product_source).process_csv
  end

  def initialize(mid: 1237, rewrite: false, update: true, daily: nil, product_source: nil)
    @retailer = RETAILERS[mid.to_i]
    @mid = mid
    @update = update
    @daily = daily
    @product_source = product_source
    @rewrite = rewrite
  end

  def get_file
    filename = "tmp/sources/#{@mid}_2388513_mp#{"_delta" if @daily}.txt"
    filename_gz = "#{filename}.gz"

    ftp = Net::FTP.new('aftp.linksynergy.com')
    ftp.login ENV['LINKSYNERGY_FTP_LOGIN'], ENV['LINKSYNERGY_FTP_PASSWORD']

    @file_updated = false

    if !File.exists?(filename) || ftp_mtime(ftp, File.basename(filename_gz)) > File.mtime(filename)
    # if !File.exists?(filename) || File.mtime(filename) < 12.hours.ago
      ftp.getbinaryfile(File.basename(filename_gz), filename_gz)
      txt = Zlib::GzipReader.open(filename_gz).read
      File.write(Rails.root.join(filename), txt)
      File.delete(filename_gz)
      @file_updated = true
    end

    filename
  end

  def process_csv
    begin
      filename = get_file
    rescue Net::FTPPermError => e
      @product_source.update_columns collect_status_code: :fail, collect_status_message: e.message.strip
      return false
    end

    return false unless @file_updated

    columns = %w(
      id title part_number category_primary category_secondary url image emtp1 description_short description_full empt2
      discount_type price_sale price_retail empt3 empt4 brand numb1 bool1 style_code brand2 empt5 instock gtin numb2 currency id3
      url2 empt6 category3 size empt7 color sex empt8 empt9 empt10 empt11 char
    ).map(&:to_sym)

    return false unless filename

    first_line = File.open(filename) {|f| f.readline}.split('|')
    if @retailer && @retailer != first_line[2]
      Product.where(source: source, retailer: @retailer).update_all(retailer: first_line[2])
    end
    @retailer = first_line[2]
    if @rewrite
      Product.where(source: source, retailer: @retailer).delete_all
    end

    chunk = []
    chunk_limit = 1_000
    File.readlines(filename).each do |line|
      row = line.split('|')
      next if row[0] == 'HDR' || row[0] == 'TRL'

      row.pop # new line sep

      hash = Hash[columns.zip(row)]

      if chunk.size < chunk_limit
        chunk << hash
      else
        process_rows chunk
        chunk = []
      end
    end

    if chunk.size > 0
      process_rows chunk
      chunk = []
    end

    # SmarterCSV.process(filename, headers_in_file: false, col_sep: '|', force_simple_split: true, user_provided_headers: columns, chunk_size: 1_000, verbose: Rails.env.development?) do |rows|
    #   process_rows rows
    # end

    true
  end

  def process_rows rows
    rows.select!{|r| r[:gtin] != 'HDR' && r[:gtin] != 'TRL'}

    items = prepare_data(rows)

    @exists_products = Product.where(source: source, retailer: @retailer, source_id: items.map{|r| r[:source_id]})
    to_update = []
    to_create = []
    items.each do |r|
      (r[:source_id].in?(@exists_products.map(&:source_id)) ? to_update : to_create) << r
    end

    process_to_create(to_create)
    process_to_update(to_update) if @update
  end

  def prepare_data rows
    results = []
    rows.each do |r|
      item = {
        source: source,
        source_id: r[:id],
        title: r[:title],
        url: r[:url],
        image: r[:image],
        brand: r[:brand],
        style_code: r[:style_code],
        size: r[:size],
        color: r[:color],
        retailer: @retailer,
        price: r[:price_retail],
        price_sale: r[:price_sale],
        description: r[:description_full],
        upc: r[:gtin]
      }

      results << item if item[:upc].present?
    end

    prepare_items(results)

    results
  end

  def process_to_create to_create
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
      product = @exists_products.select{|pr| pr.source_id == row[:source_id]}.first
      row.delete :upc unless row[:upc].present?
      row.delete :size unless row[:size].present?
      row.delete :color unless row[:color].present?
      product.attributes = row
      product.save! if product.changed?
    end
  end

  def ftp_mtime(ftp, filename)
    datetime = ftp.list("#{filename}*").first.match(/ftpgroup\s+\d+\s(.*)\s#{Regexp.quote filename}$/) && $1
    Time.parse "#{datetime} UTC"
  end

  def self.build_file_url(mid, type: :delta)
    "ftp://#{ENV['LINKSYNERGY_FTP_LOGIN']}:#{ENV['LINKSYNERGY_FTP_PASSWORD']}@aftp.linksynergy.com/#{mid}_2388513_mp#{"_delta" if type.to_sym == :delta}.txt.gz"
  end
end
