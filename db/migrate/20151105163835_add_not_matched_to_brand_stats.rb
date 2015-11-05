class AddNotMatchedToBrandStats < ActiveRecord::Migration
  def change
    add_column :brand_stats, :not_matched, :integer
    add_index :brand_stats, :not_matched
    add_index :brand_stats, :shopbop_nothing_size
    add_index :brand_stats, :updated_at
  end
end
