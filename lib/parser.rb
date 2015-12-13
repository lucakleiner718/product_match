class Parser

	def self.find_upc url
		resp = Typhoeus.get(url)
		upc_list = resp.body.scan(/\D\d{11,14}\D/)
		upc_list.map{|r| r.match(/\d{11,14}/)[0]}.uniq
	end

end