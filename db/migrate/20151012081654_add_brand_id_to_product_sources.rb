class AddBrandIdToProductSources < ActiveRecord::Migration
  def change
    add_column :product_sources, :brand_id, :integer
    add_index :product_sources, :brand_id
  end
end
