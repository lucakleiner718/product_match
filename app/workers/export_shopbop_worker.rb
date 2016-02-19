class ExportShopbopWorker

  include Sidekiq::Worker
  sidekiq_options queue: :critical, unique: true

  def perform(period, time_start=nil)
    weekly(time_start) if period == 'last'
    current_week if period == 'current'
  end

  private

  def weekly(time_start)
    ts = (time_start ? time_start.to_datetime : 1.week.ago).monday.beginning_of_day
    te = ts.sunday.end_of_day
    products_ids = ProductUpc.where('created_at >= ? AND created_at <= ?', ts, te).pluck(:product_id)
    csv_string = CSV.generate do |csv|
      Product.where(id: products_ids).each do |product|
        csv << [product.source_id, product.upc]
      end
    end
    File.write("public/downloads/shopbop_products_upc-#{te.strftime('%m_%d_%y')}-archive.csv", csv_string)
  end

  def current_week
    ts = Time.zone.now.monday
    products_ids = ProductUpc.where('created_at >= ?', ts).pluck(:product_id)
    csv_string = CSV.generate do |csv|
      Product.where(id: products_ids).each do |product|
        csv << [product.source_id, product.upc]
      end
    end
    File.write("public/downloads/shopbop_products_upc.csv", csv_string)
  end

end
