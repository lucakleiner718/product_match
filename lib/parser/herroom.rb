class Parser::Herroom

	include Parser::ServiceObject

	def self.get_all_product_links
		domain = 'http://www.herroom.com'

		brands_list = Curl.get("#{domain}/brands.aspx").body
		html = Nokogiri::HTML(brands_list)
		
		brands_links = html.css(".brands a").map{|link| link.attr('href')}

		links = []

		brands_links.each do |brand_link|
			brand_page = Curl.get("#{domain}#{brand_link}").body
			brand_page_html = Nokogiri::HTML(brand_page)
			links += brand_page_html.css('table tr td.borderz .img-holder a').map{|l| l.attr('href')}

			pagination_links = brand_page_html.css('.page_nav .pagingsq a').map{|l| l.attr('href')}
			pagination_links.each do |pagination_link|
				brand_page = Curl.get("#{domain}/#{pagination_link}").body
				brand_page_html = Nokogiri::HTML(brand_page)
				links += brand_page_html.css('table tr td.borderz .img-holder a').map{|l| l.attr('href')}				
			end

			puts "Links: #{links.size}"
		end

		Dir.mkdir('tmp/herroom')
		results_filename = 'tmp/herroom/products-links.csv'
		File.write results_filename, links.join("\n")
	end

	def self.perform url
		instance = self.new
		data = instance.process url
		instance.save_data data if data
	end

	def self.process_products
		instance = self.new
		exists_files = Dir.glob('tmp/herroom/*.csv')
		links = File.read('tmp/herroom/products-links.csv').split("\n")
		links.each do |link|
			filename = "tmp/herroom/#{link.sub('.shtml', '.csv')}"
			next if exists_files.include?(filename)
			url = "http://www.herroom.com/#{link}"
			data = instance.process(url)
			unless data
				puts "skip #{link}"
				next
			end
			puts "process #{link}"

			header = data.first.keys.map(&:to_s).map(&:titleize)
			csv_string = CSV.generate do |csv|
				csv << header
				data.each do |row|
					csv << row.values
				end
			end
			
			File.write filename, csv_string

			filename
		end
	end

	def self.join_files
		exists_files = Dir.glob('tmp/herroom/*.csv')
		results = {}
		header = nil
		exists_files.each do |file|
			filename = file.sub('tmp/herroom/', '')
			next if filename == 'herrom-products-links.csv' || filename[0] == '_'

			results[filename[0]] ||= []
			csv = CSV.read(file)
			h = csv.shift
			header ||= h

			results[filename[0]] += csv
		end

		results.each do |letter, data|
			csv_string = CSV.generate do |csv|
				csv << header
				data.each do |row|
					csv << row
				end
			end

			File.write "tmp/herroom/_letter-#{letter}.csv", csv_string
		end

		csv_string = CSV.generate do |csv|
			csv << header
			results.each do |l, data|
				data.each do |row|
					csv << row
				end
			end
		end

		File.write "tmp/_herroom-letters-all.csv", csv_string
	end

	def process url
		resp = Curl.get(url)
		return false if resp.response_code != 200
		
		page = resp.body
		html = Nokogiri::HTML(page)

		results = []

		product_name = html.css('#product-name h1').text
		product_id = html.css('#hdnStyleNumber').first.attr('value')
		category = html.css('.crumbtrail a').inject([]){|ar, el| el.text == 'home' ? '' : ar << el.text; ar}.join(' > ')
		basic_price = html.css('.itemPrice').text

		begin
      images = html.css('.product-thumbs-wrapper a.product-thumbnail').map{|a| a.attr('rel').match(/largeimage:\s?\'([^\']+)\'/)[1]}
			brand = page.match(/\'brand\' \: \'([^\']+)'/)[1]
			id = page.match(/\'id\' \: \'[^-]+\-(.+)'/)[1]
		rescue => e
			binding.pry
		end

		variants = html.css('#hdnSizeColors').first.attr('value')
		return false if variants.blank?

		data = JSON.parse variants.gsub("'", '"')
		data.each do |row|
			results << {
				id: id,
				brand: brand,
				product_name: product_name.sub(/^#{Regexp.quote brand}\s?/i, '').sub(/\s?#{id}$/i, ''),
				category: category,
				price: (row['SalePrice'] == '$0.00' ? basic_price : row['SalePrice']),
				color_name: row['ColorName'],
				color_value: row['ColorCode'],
				size_name: row['Size'],
				style_id: product_id,
				upc: row['SKU'],
				original_url: url,
        images: images.join(',')
			}
		end

		results
	end

	def save_data data
		header = data.first.keys.map(&:to_s).map(&:titleize)
		csv_string = CSV.generate do |csv|
			csv << header
			data.each do |row|
				csv << row.values
			end
		end
		filename = "tmp/herroom/herroom-#{Time.now.to_i}.csv"
		File.write filename, csv_string

		filename
	end

end