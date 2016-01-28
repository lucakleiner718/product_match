class AddDisabledToBrands < ActiveRecord::Migration
  def change
    add_column :brands, :disabled, :boolean, default: :false
  end
end
