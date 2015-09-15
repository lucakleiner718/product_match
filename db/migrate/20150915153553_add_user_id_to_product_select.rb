class AddUserIdToProductSelect < ActiveRecord::Migration
  def change
    add_column :product_selects, :user_id, :integer
    add_index :product_selects, :user_id
  end
end
