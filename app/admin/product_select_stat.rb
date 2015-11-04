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

    chart = StatChart.new.data

    render partial: 'product_stat', locals: { rows: rows, users: users, chart: chart }
  end
end