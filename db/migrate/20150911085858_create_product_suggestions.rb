class CreateProductSuggestions < ActiveRecord::Migration
  def change
    create_table :product_suggestions do |t|
      t.integer :product_id
      t.integer :suggested_id
      t.integer :percentage

      t.timestamps null: false
    end

    add_index :product_suggestions, :product_id
    add_index :product_suggestions, [:product_id, :suggested_id], unique: true

  end
end
