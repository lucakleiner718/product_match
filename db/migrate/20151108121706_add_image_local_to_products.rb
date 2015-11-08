class AddImageLocalToProducts < ActiveRecord::Migration
  def change
    add_column :products, :image_local, :string
    add_column :products, :additional_images_local, :text, array: true, default: []
  end
end
