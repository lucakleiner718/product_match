class RenameBrandToBrandName < ActiveRecord::Migration
  def change
    rename_column :products, :brand, :brand_name
  end
end
