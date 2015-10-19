class CreateProductUpcs < ActiveRecord::Migration
  def change
    create_table :product_upcs do |t|
      t.integer :product_id
      t.integer :selected_id
      t.integer :product_select_id
      t.string :upc
      t.datetime :created_at, null: false
    end

    add_index :product_upcs, :product_id, unique: true
    add_index :product_upcs, :product_select_id, unique: true
  end
end
