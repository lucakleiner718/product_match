class CreateBrands < ActiveRecord::Migration
  def change
    create_table :brands do |t|
      t.string :name
      t.text :synonyms, array: true, default: []
      t.boolean :in_use, default: false

      t.timestamps null: false
    end

    add_index :brands, :name, unique: true
    add_index :brands, :synonyms
  end
end
