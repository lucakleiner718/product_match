class CreateBrandDuplicates < ActiveRecord::Migration
  def change
    create_table :brand_duplicates do |t|
      t.integer :target_brand_id
      t.integer :duplicate_brand_id
      t.boolean :processed, default: nil
      t.datetime :processed_at

      t.timestamps null: false
    end
  end
end
