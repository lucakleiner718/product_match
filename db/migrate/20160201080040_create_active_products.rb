class CreateActiveProducts < ActiveRecord::Migration
  def change
    create_table :active_products do |t|
      t.string :title
      t.integer :brand_id
      t.string :price
      t.string :category
      t.string :source
      t.string :style_code
      t.string :image
      t.text :additional_images, array: true, default: []
      t.string :gender
      t.string :material
      t.string :google_category
      t.string :url
      t.datetime :shopbop_added_at
      t.integer :retailers_count
    end
  end
end
