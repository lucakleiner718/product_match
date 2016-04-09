class AddIndexToCreatedAtProductUpcs < ActiveRecord::Migration
  def change
    add_index :product_upcs, :created_at, order: :created_at
  end
end
