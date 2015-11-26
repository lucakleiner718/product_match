class AddCurrencyToProducts < ActiveRecord::Migration
  def change
    add_column :products, :price_currency, :string
    add_column :products, :price_sale_currency, :string
  end
end
