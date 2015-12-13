require 'open-uri'
require 'xml_parser'

class Import::Platform::Bop < Import::Base

  def csv_col_sep; ','; end

  def self.perform url=nil, force=false
    instance = self.new
    instance.perform url, force
  end

  def perform url=nil, force=false
    raise Exception, "Should be overriden by parent class"
  end

  private

  def get_file(url=nil)
    url ||= default_file
    extension = url.match(/\.([a-z]+)$/)[1]
    filename = "tmp/sources/#{self.class.name.match(/::([a-z]+)/i)[1].downcase}.#{extension}"

    @file_updated = false
    if !File.exists?(filename) || (url_mtime(url) > File.mtime(filename))
      body = get_request(url).body
      body.force_encoding('UTF-8')
      File.write filename, body
      @file_updated = true
    end

    filename
  end

  def process_batch(filename)
    if filename =~ /\.csv$/
      SmarterCSV.process(filename, col_sep: csv_col_sep, chunk_size: 5_000) do |rows|
        yield rows
      end
    elsif filename =~ /\.xml$/
      puts "start process file #{filename}"
      columns = %w|item_group_id id title description product_type google_product_category link image_link
        condition availability price sale_price brand gender color size material shipping
        additional_image_link additional_image_link1 additional_image_link2 additional_image_link3
        additional_image_link4 ean upc|

      batch = []
      Xml::Parser.factory(filename) do
        row = {}
        inside_element 'product' do
          next if inner_xml.blank?
          columns.each do |column|
            for_element column do
              row[column] = HTMLEntities.new.decode(inner_xml)
            end
          end
        end
        next if row.blank?
        batch << row.symbolize_keys!

        if batch.size >= 5_000
          yield batch
        end
      end
    end
  end

  def process_create(to_create)
    if to_create.size > 0
      keys = to_create.first.keys
      keys += [:match, :created_at, :updated_at]
      tn = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      sql = "INSERT INTO products
                (#{keys.join(',')})
                VALUES #{to_create.map{|r| "(#{r.values.concat([true, tn, tn]).map{|el| Product.sanitize(el.is_a?(Array) ? "{#{el.join(',')}}" : el)}.join(',')})"}.join(',')}
                RETURNING id"
      resp = Product.connection.execute sql
      resp.map{|r| r['id'].to_i}
    else
      []
    end
  end

end
