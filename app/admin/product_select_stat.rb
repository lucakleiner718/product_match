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

    table class: 'index_table' do
      thead do
        tr do
          ['User', 'Items Matched', 'Items Nothing', 'Items No Color', 'Items No Size'].each &method(:th)
        end
      end
      tbody do
        rows.each do |user_id, selects|
          tr do
            td users[user_id] || 'N/A'
            td selects['found'] || 0
            td selects['nothing'] || 0
            td selects['no-color'] || 0
            td selects['no-size'] || 0
          end
        end
      end
    end
  end
end