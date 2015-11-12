class ExportShopbopWorker

  include Sidekiq::Worker

  def perform time_start=nil
    ts = (time_start ? time_start.to_datetime : 1.week.ago).monday.beginning_of_day
    te = ts.sunday.end_of_day
    products_ids = ProductUpc.where('created_at >= ? AND created_at <= ?', ts, te).pluck(:product_id)
    csv_string = CSV.generate do |csv|
      Product.where(id: products_ids).each do |product|
        csv << [product.source_id, product.upc]
      end
    end
    File.write("public/downloads/shopbop_products_upc-#{te.strftime('%m_%d_%y')}-archive.csv", csv_string)


    ts = Time.now.monday
    products_ids = ProductUpc.where('created_at >= ?', ts).pluck(:product_id)
    # products_ids = Product.where('products.created_at >= ?', ts)
    #                  .joins('RIGHT JOIN product_upcs ON product_upcs.product_id=products.id')
    #                  .pluck(:product_id)
    csv_string = CSV.generate do |csv|
      Product.where(id: products_ids).each do |product|
        csv << [product.source_id, product.upc]
      end
    end
    File.write("public/downloads/shopbop_products_upc.csv", csv_string)
  end

end