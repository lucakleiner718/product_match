class Export::Brands

  def self.perform
    header = ['Brand']
    retailers = Product.select('distinct(retailer)').map(&:retailer).compact
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
          row << products.select{|r| r[0] == retailer}.size
          row << products.select{|r| r[0] == retailer && r[1].present?}.size
        end
        csv << row
      end
    end

    filename = "brand-data-#{Time.now.to_i}.csv"
    File.write Rails.root.join("public/#{filename}"), csv_string
    "http://upc.socialrootdata.com/#{filename}"
  end

end