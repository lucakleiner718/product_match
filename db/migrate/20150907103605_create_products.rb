class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :brand
      t.string :source
      t.string :source_id
      t.string :kind
      t.string :retailer
      t.string :title
      t.string :category
      t.string :url
      t.string :image
      t.text :additional_images, array: true, default: []
      t.string :price
      t.string :price_sale
      t.string :color
      t.string :size
      t.string :material
      t.string :gender

      t.string :upc
      t.string :mpn
      t.string :ean
      t.string :sku
      t.string :style_code

      t.string :item_group_id
      t.string :google_category

      t.text :description

      t.timestamps null: false
    end

    add_index :products, [:source, :source_id]
    add_index :products, :brand
    add_index :products, :title
    add_index :products, :color
    add_index :products, :size
    add_index :products, :upc
    add_index :products, :mpn
    add_index :products, :ean
    add_index :products, :style_code
  end
end
