class AddDecisionToProductSelects < ActiveRecord::Migration
  def change
    add_column :product_selects, :decision, :string
  end
end
