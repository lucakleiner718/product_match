class Import::Demandware < Import::Base

  # def self.perform website_url
  #   instance = self.new
  #   instance.perform website_url
  # end
  #
  # def perform website_url
  #
  # end
  #
  # def process_url url
  #   resp = Curl.get(url)
  #   return false if resp.response_code != 200
  #
  #   page = resp.body
  #   html = Nokogiri::HTML(page)
  #
  #   results = []
  #
  #   binding.pry
  #
  #   product_name = html.css('.product-name').text.strip
  #   product_id = html.css('#container').attr('data-pid').text
  #   param_product_id = product_id.gsub('_', '__').gsub('%2b', '%2B').gsub('+', '%2B')
  #
  #   category = html.css('.product-breadcrumbs li a').inject([]){|ar, el| el.text == 'Home' ? '' : ar << el.text; ar}.join(' > ')
  #
  #
  #
  #   colors = html.css('.product-variations .attribute .Color li.available a')
  #   colors.each do |color|
  #     color_name = color.text.strip
  #     color_id = color.attr('data-color')
  #
  #     color_link = "#{BASEURL}/on/demandware.store/#{SUBDIR}/default/Product-Variation?pid=#{product_id.sub('+', '%2B')}&dwvar_#{param_product_id}_color=#{color_id}&format=ajax"
  #     detail_color_page = Curl.get(color_link) do |http|
  #       http.headers['Referer'] = url
  #       http.headers['X-Requested-With'] = 'XMLHttpRequest'
  #       http.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36'
  #     end
  #     color_html = Nokogiri::HTML(detail_color_page.body)
  #     sizes = color_html.css('#va-size option').select{|r| r.attr('value') != ''}
  #
  #     if sizes.size > 0
  #       sizes.each do |item|
  #         size_name = item.text.strip
  #         next if size_name =~ / - Out of Stock$/i
  #
  #         # begin
  #         size_value = item.attr('value').match(/dwvar_#{param_product_id}_size=([^&]+)/i)[1]
  #
  #         # rescue => e
  #         # 	binding.pry
  #         # end
  #
  #         link = "#{BASEURL}/on/demandware.store/#{SUBDIR}/default/Product-Variation?pid=#{product_id.sub('+', '%2B')}&dwvar_#{param_product_id}_size=#{size_value}&dwvar_#{param_product_id}_color=#{color_id}&format=ajax"
  #         puts link
  #
  #         # link = item.attr('value')
  #         size_page = Curl.get(link) do |http|
  #           http.headers['Referer'] = url
  #           http.headers['X-Requested-With'] = 'XMLHttpRequest'
  #           http.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36'
  #         end
  #
  #         next if size_page.response_code != 200
  #
  #         size_page_body = size_page.body
  #         # File.write "tmp/html-response-#{Time.now.to_i}.html", size_page_body
  #         size_html = Nokogiri::HTML(size_page_body)
  #
  #         # begin
  #         price = size_html.css('.price-sales').first.text.strip
  #         # rescue => e
  #         # 	binding.pry
  #         # end
  #
  #         upc = size_html.css('#pid').first.attr('value')
  #         binding.pry if upc !~ /^\d+$/
  #
  #         results << {
  #           product_name: product_name,
  #           category: category,
  #           price: price,
  #           color: color_name,
  #           size_name: size_name,
  #           size_value: URI.decode(size_value),
  #           style_id: product_id,
  #           upc: upc,
  #           original_url: url
  #         }
  #       end
  #     else
  #       size = 'N/A'
  #       upc = html.css('#pid').first.attr('value')
  #       price = html.css('.price-sales').first.text.strip
  #
  #       results << {
  #         product_name: product_name,
  #         category: category,
  #         price: price,
  #         color: color_name,
  #         size_name: size,
  #         size_value: '',
  #         style_id: product_id,
  #         upc: upc,
  #         original_url: url
  #       }
  #     end
  #   end
  #
  #   results
  # end
  #
  # # @example:
  # #   Parser::Dvf.perform_urls File.read('tmp/source2.csv').split("\n")
  # def self.perform_urls urls
  #   instance = self.new
  #   results = []
  #   skipped = 0
  #   # progress = ProgressBar.new
  #
  #   urls.each do |url|
  #     data = instance.process url
  #     if data
  #       results.concat data
  #     else
  #       skipped += 1
  #     end
  #     # progress.increment!
  #   end
  #   puts "Skipped: #{skipped}"
  #   instance.save_data results
  # end
  #
  # def out_of_stock
  #   @out_of_stock
  # end
  #
  # def out_of_stock=out_of_stock
  #   @out_of_stock = out_of_stock
  # end
  #
  # def save_data data
  #   header = data.first.keys.map(&:to_s).map(&:titleize)
  #   csv_string = CSV.generate do |csv|
  #     csv << header
  #     data.each do |row|
  #       csv << row.values
  #     end
  #   end
  #   filename = "tmp/demandware-#{NAME}-#{Time.now.to_i}.csv"
  #   File.write filename, csv_string
  #
  #   filename
  # end
end