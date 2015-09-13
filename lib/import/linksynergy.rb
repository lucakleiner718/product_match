require 'net/ftp'

class Import::Linksynergy < Import::Base

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

  def self.perform mid: 1237, rewrite: false, update: true
    instance = self.new mid: mid, rewrite: rewrite, update: update
    instance.process_csv
  end

  def initialize mid: 1237, rewrite: false, update: true
    @retailer = RETAILERS[mid.to_i]
    @mid = mid
    @update = update

    if rewrite
      Product.where(source: source, retailer: @retailer).delete_all
    end
  end

  def process_xml
    filename = "tmp/sources/#{@mid}_2388513_mp.xml"
    xml = Nokogiri::XML(File.read(filename))
    binding.pry
  end

  def get_file
    filename = "tmp/sources/#{@mid}_2388513_mp.txt"

    unless File.exists? filename
      ftp = Net::FTP.new('aftp.linksynergy.com')
      ftp.login ENV['LINKSYNERGY_FTP_LOGIN'], ENV['LINKSYNERGY_FTP_PASSWORD']
      ftp.getbinaryfile("#{@mid}_2388513_mp.txt.gz", Rails.root.join("tmp/sources/#{@mid}_2388513_mp.txt.gz"), 1024)
      gz_file = Rails.root.join("tmp/sources/#{@mid}_2388513_mp.txt.gz")
      txt = Zlib::GzipReader.open(gz_file).read
      File.write Rails.root.join("tmp/sources/#{@mid}_2388513_mp.txt"), txt
      File.delete gz_file
    end

    filename
  end

  def process_csv
    filename = get_file

    columns = %w(id title id2 category1 category2 url image emtp1 description_short description_full empt2 amount price_sale price_retail empt3 empt4 brand numb1 bool1 style_code brand2 empt5 instock upc numb2 currency id3 url2 empt6 category3 size empt7 color sex empt8 empt9 empt10 empt11 char).map(&:to_sym)

    return false unless filename

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
  end

  def process_rows rows
    rows.select!{|r| r[:id] != 'HDR' && r[:id] != 'TRL'}

    items = prepare_data rows

    @exists_products = Product.where(source: 'linksynergy', retailer: @retailer, source_id: items.map{|r| r[:source_id]})
    to_update = []
    to_create = []
    items.each do |r|
      (r[:source_id].in?(@exists_products.map(&:source_id)) ? to_update : to_create) << r
    end

    process_to_create to_create
    process_to_update to_update if @update
  end

  def prepare_data rows
    items = []
    rows.each do |r|
      item = {
        source: source,
        source_id: r[:id],
        title: normalize_title(r[:title], r[:brand]),
        url: r[:url],
        image: r[:image],
        brand: normalize_brand(r[:brand]),
        style_code: r[:style_code],
        upc: r[:upc],
        size: r[:size],
        color: r[:color],
        retailer: @retailer,
        price: r[:price_retail],
        price_sale: r[:price_sale],
        description: r[:description_full],
      }

      items << item
    end
    items
  end

  def process_to_create to_create
    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:created_at, :updated_at]
      tn = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([tn, tn]).map{|el| Product.sanitize el}.join(',')})"}.join(',')}"
      Product.connection.execute sql
    end
  end

  def process_to_update to_update
    to_update.each do |row|
      product = @exists_products.select{|pr| pr.source_id == row[:source_id]}.first
      product.attributes = row
      product.save if product.changed?
    end
  end

  def source
    'linksynergy'
  end

end