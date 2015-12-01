class RemovePriceSaleCurrencyFromProducts < ActiveRecord::Migration
  def change
    remove_column :products, :price_sale_currency, :string
  end
end
