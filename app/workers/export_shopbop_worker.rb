class ExportShopbopWorker

  include Sidekiq::Worker

  def perform

    selected_products_found = ProductSelect.where(decision: 'found').pluck(:product_id, :selected_id).uniq{|el| el[0]}

    selected = {}
    selected_products_found.map{|el| el.last}.in_groups_of(10_000, false) do |ids|
      selected.merge! Product.where(id: ids).with_upc.pluck(:id, :upc).inject({}){|obj, pr| obj[pr[0]] = pr[1]; obj}
    end

    products = {}
    selected_products_found.in_groups_of(10_000, false) do |ids|
      products.merge! Product.shopbop.where(id: ids).pluck(:id, :source_id).inject({}){|obj, pr| obj[pr[0]] = pr[1]; obj}
    end

    data = selected_products_found.map do |(product_id, selected_id)|
      [products[product_id], selected[selected_id]]
    end

    csv_string = CSV.generate do |csv|
      data.each do |row|
        csv << row
      end
    end

    File.write('public/downloads/shopbop_products_upc.csv', csv_string)
  end

end