class AddInStoreToProducts < ActiveRecord::Migration
  def change
    add_column :products, :in_store, :boolean, default: false
    add_index :products, :in_store
  end
end
