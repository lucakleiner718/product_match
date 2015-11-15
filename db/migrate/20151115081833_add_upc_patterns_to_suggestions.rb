class AddUpcPatternsToSuggestions < ActiveRecord::Migration
  def change
    add_column :product_suggestions, :upc_patterns, :text, array: true, default: []
  end
end
