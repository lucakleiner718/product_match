class Export::Brands

  def self.perform
    header = ['Brand']
    retailers = Product.select('distinct(retailer)').map(&:retailer).compact.sort
    retailers.each do |retailer|
      header << "#{retailer} Total"
      header << "#{retailer} has UPC"
    end

    csv_string = CSV.generate do |csv|
      csv << header

      Brand.order(:name).each do |brand|
        products = Product.where(brand: brand.names).where.not(retailer: nil).pluck(:retailer, :upc)

        row = []
        row << brand.name
        retailers.each do |retailer|
          size_total = products.select{|r| r[0] == retailer}.size
          size_with_upc = products.select{|r| r[0] == retailer && r[1].present?}.size
          row << (size_total > 0 ? size_total : '')
          row << (size_with_upc > 0 ? size_with_upc : '')
        end
        csv << row
      end
    end

    filename = "brand-data-#{Time.now.to_i}.csv"
    File.write Rails.root.join("public/#{filename}"), csv_string
    "http://upc.socialrootdata.com/#{filename}"
  end

end