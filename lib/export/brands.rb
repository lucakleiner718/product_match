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

      Brand.all.each do |brand|
        products = Product.where(brand: brand.name).where.not(retailer: nil).pluck(:retailer, :upc)

        row = []
        row << brand.name
        retailers.each do |retailer|
          row << products.select{|r| r[0] == retailer}.size
          row << products.select{|r| r[0] == retailer && r[1].present?}.size
        end
        csv << row
      end
    end

    File.write "tmp/brand-data-#{Time.now.to_i}.csv", csv_string
  end

end