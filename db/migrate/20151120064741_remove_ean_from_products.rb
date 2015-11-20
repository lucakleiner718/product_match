class RemoveEanFromProducts < ActiveRecord::Migration
  def change
    remove_column :products, :ean, :string
  end
end
