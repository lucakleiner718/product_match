class AddSourceStyleCodeIndexProducts < ActiveRecord::Migration
  def change
    add_index :products, [:source, :style_code]
  end
end
