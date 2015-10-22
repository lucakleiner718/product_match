ActiveAdmin.register_page "Product Select Stat" do

  content do
    data = ProductSelect.pluck(:user_id, :decision)
    users = User.where(id: data.map(&:first).uniq).inject({}){|obj, u| obj[u.id] = u.email; obj}
    rows = {}

    data.each do |row|
      rows[row[0]] ||= {}
      rows[row[0]][row[1]] ||= 0
      rows[row[0]][row[1]] += 1
    end

    chart = {
      total: [],
      empty: [],
      matched: []
    }

    matched = ProductUpc.connection.execute("
      SELECT count(*), EXTRACT(YEAR FROM created_at)::text || '-' || EXTRACT(WEEK FROM created_at)::text AS created_week
      FROM product_upcs
      GROUP BY created_week
    ")
    chart[:matched] = matched.sort{|a,b| a['created_week'] <=> b['created_week']}.map{|el| week = el['created_week'].split('-')
                      .map(&:to_i); [Date.commercial(week.first, week.last, 1).to_time.to_i*1000, el['count'].to_i]}

    render partial: 'product_stat', locals: { rows: rows, users: users, chart: chart }
  end
end