class AddIndexSuggestedIdToProductSuggestions < ActiveRecord::Migration
  def change
    add_index :product_suggestions, :suggested_id
    add_index :product_suggestions, :percentage
  end
end
