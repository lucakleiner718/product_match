class AddSkuIndexToProducts < ActiveRecord::Migration
  def change
    add_index :products, :sku
  end
end
