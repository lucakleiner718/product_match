class AddPricesToSuggestions < ActiveRecord::Migration
  def change
    add_column :product_suggestions, :price, :string
    add_column :product_suggestions, :price_sale, :string
  end
end
