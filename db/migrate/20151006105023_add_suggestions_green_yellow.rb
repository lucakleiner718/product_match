class AddSuggestionsGreenYellow < ActiveRecord::Migration
  def change
    add_column :brand_stats, :suggestions_green, :integer
    add_column :brand_stats, :suggestions_yellow, :integer
    add_index :brand_stats, :suggestions_green
    add_index :brand_stats, :suggestions_yellow

    add_index :brand_stats, :shopbop_size
    add_index :brand_stats, :shopbop_noupc_size
    add_index :brand_stats, :shopbop_matched_size
    add_index :brand_stats, :amounts_values
    add_index :brand_stats, :suggestions
  end
end
