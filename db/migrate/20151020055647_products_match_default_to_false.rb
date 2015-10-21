class ProductsMatchDefaultToFalse < ActiveRecord::Migration
  def change
    change_column :products, :match, :boolean, default: false
  end
end
