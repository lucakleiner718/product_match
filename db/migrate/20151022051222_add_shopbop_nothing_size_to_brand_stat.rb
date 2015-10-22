class AddShopbopNothingSizeToBrandStat < ActiveRecord::Migration
  def change
    add_column :brand_stats, :shopbop_nothing_size, :integer
  end
end
