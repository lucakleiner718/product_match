class CreateBrandStats < ActiveRecord::Migration
  def change
    create_table :brand_stats do |t|
      t.integer :brand_id

      t.integer :shopbop_size
      t.integer :shopbop_noupc_size
      t.integer :shopbop_matched_size
      t.string :amounts_content
      t.integer :amounts_values
      t.integer :suggestions

      t.datetime :updated_at, null: false
    end

    add_index :brand_stats, :brand_id, unique: true
  end
end
