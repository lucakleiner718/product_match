class Parser

	def self.find_upc url
		resp = Curl.get(url)
		upc_list = resp.body.scan(/\D\d{12,14}\D/)
		upc_list.map{|r| r.match(/\d{12,14}/)[0]}.uniq
	end

end