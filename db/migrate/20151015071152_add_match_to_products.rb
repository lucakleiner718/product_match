class AddMatchToProducts < ActiveRecord::Migration
  def change
    add_column :products, :match, :boolean, default: true
    add_index :products, :match
  end
end
