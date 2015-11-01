class AddSourceIndexToProducts < ActiveRecord::Migration
  def change
    add_index :products, :source
  end
end
