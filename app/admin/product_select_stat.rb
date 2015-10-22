ActiveAdmin.register_page "Product Select Stat" do

  content do
    timeframe = 6.months

    data = ProductSelect.pluck(:user_id, :decision)
    users = User.where(id: data.map(&:first).uniq).inject({}){|obj, u| obj[u.id] = u.email; obj}
    rows = {}

    data.each do |row|
      rows[row[0]] ||= {}
      rows[row[0]][row[1]] ||= 0
      rows[row[0]][row[1]] += 1
    end

    chart = {
      total_products: [],
      total_without_upc: [],
      added_without_upc: [],
      matched: []
    }

    stats = StatAmount.where('date > ?', 6.months.ago).where(key: ['shopbop_total', 'not_matched_size'])
    stats.each do |s|
      if s.key == 'shopbop_total'
        chart[:total_products] << [s.date.to_time(:utc).to_i*1000, s.value]
      elsif s.key == 'not_matched_size'
        chart[:total_without_upc] << [s.date.to_time(:utc).to_i*1000, s.value]
      end
    end

    added_without_upc = ProductUpc.connection.execute("
      SELECT count(*), EXTRACT(YEAR FROM created_at)::text || '-' || EXTRACT(WEEK FROM created_at)::text AS created_week
      FROM products
      WHERE source='shopbop' AND (upc is null OR upc = '') AND created_at > '#{timeframe.ago}'
      GROUP BY created_week
    ")
    chart[:added_without_upc] = added_without_upc.sort{|a,b| a['created_week'] <=> b['created_week']}.map{|el| week = el['created_week'].split('-')
                                     .map(&:to_i); [Date.commercial(week.first, week.last, 7).to_time(:utc).to_i*1000, el['count'].to_i]}

    matched = ProductUpc.connection.execute("
      SELECT count(*), EXTRACT(YEAR FROM created_at)::text || '-' || EXTRACT(WEEK FROM created_at)::text AS created_week
      FROM product_upcs
      WHERE created_at > '#{timeframe.ago}'
      GROUP BY created_week
    ")
    chart[:matched] = matched.sort{|a,b| a['created_week'] <=> b['created_week']}.map{|el| week = el['created_week'].split('-')
                             .map(&:to_i); [Date.commercial(week.first, week.last, 7).to_time(:utc).to_i*1000, el['count'].to_i]}

    # binding.pry

    render partial: 'product_stat', locals: { rows: rows, users: users, chart: chart }
  end
end