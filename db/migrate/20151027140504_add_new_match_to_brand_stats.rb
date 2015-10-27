class AddNewMatchToBrandStats < ActiveRecord::Migration
  def change
    add_column :brand_stats, :new_match_today, :integer
    add_column :brand_stats, :new_match_week, :integer

    add_index :brand_stats, :new_match_today
    add_index :brand_stats, :new_match_week
  end
end
