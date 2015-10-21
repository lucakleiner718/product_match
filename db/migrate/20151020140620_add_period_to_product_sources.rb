class AddPeriodToProductSources < ActiveRecord::Migration
  def change
    add_column :product_sources, :period, :integer, null: false, default: 0
  end
end
