class CreateProductSelects < ActiveRecord::Migration
  def change
    create_table :product_selects do |t|
      t.integer :product_id
      t.integer :selected_id
      t.integer :selected_percentage

      t.timestamps null: false
    end
  end
end
