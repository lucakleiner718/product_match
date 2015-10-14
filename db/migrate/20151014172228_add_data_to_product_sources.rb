class AddDataToProductSources < ActiveRecord::Migration
  def change
    add_column :product_sources, :data, :json
  end
end
