# require 'xml_parser'

module Import
  module FileImport
    def default_file; nil; end

    private

    def get_file(url)
      source_filename = File.basename(url)
      filename = "tmp/sources/#{self.class.name.match(/::([a-z]+)/i)[1].downcase}-#{source_filename}"
      filename_tmp = "tmp/sources/#{self.class.name.match(/::([a-z]+)/i)[1].downcase}_#{Time.now.to_i}-#{source_filename}"

      @file_updated = false
      if !File.exists?(filename) || (url_mtime(url) > File.mtime(filename))
        body = get_request(url).body
        body.force_encoding('UTF-8')
        File.write(filename_tmp, body)
        @file_updated = true

        filename_tmp
      else
        filename
      end
    end

    def replace_original_tmp_file(filename_tmp, url)
      source_filename = File.basename(url)
      filename = "tmp/sources/#{self.class.name.match(/::([a-z]+)/i)[1].downcase}-#{source_filename}"
      File.delete(filename) if File.exists?(filename)
      File.rename(filename_tmp, filename)
    end

    def process_batch(filename)
      if filename =~ /\.csv$/
        SmarterCSV.process(filename, col_sep: csv_col_sep, chunk_size: 5_000) do |rows|
          yield rows
        end
      elsif filename =~ /\.xml$/
        # process_xml(filename)
      end
    end

    def process_xml(filename)
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
end
