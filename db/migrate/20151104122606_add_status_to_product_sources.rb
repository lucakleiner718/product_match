class AddStatusToProductSources < ActiveRecord::Migration
  def change
    add_column :product_sources, :collect_status_code, :string
    add_column :product_sources, :collect_status_message, :string
    add_index :product_sources, :collect_status_code
  end
end
