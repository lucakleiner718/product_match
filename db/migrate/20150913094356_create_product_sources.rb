class CreateProductSources < ActiveRecord::Migration
  def change
    create_table :product_sources do |t|
      t.string :brand_name
      t.string :source_name
      t.string :source_id
      t.datetime :collected_at

      t.timestamps null: false
    end

    add_index :product_sources, :brand_name
    add_index :product_sources, [:source_name, :source_id], unique: true
  end
end
