class AddSourceRetailerIndexToProducts < ActiveRecord::Migration
  def change
    add_index :products, [:source, :retailer]
  end
end
