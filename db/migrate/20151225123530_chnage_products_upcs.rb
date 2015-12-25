class ChnageProductsUpcs < ActiveRecord::Migration
  def up
    add_column :product_upcs, :selected_ids, :text, array: true, defaut: []
    add_column :product_upcs, :product_select_ids, :text, array: true, defaut: []

    ProductUpc.all.each do |product_upc|
      product_upc.selected_ids = [product_upc.selected_id]
      product_upc.product_select_ids = [product_upc.product_select_id]
      product_upc.save
    end

    remove_column :product_upcs, :selected_id
    remove_column :product_upcs, :product_select_id
  end

  def down
    add_column :product_upcs, :selected_id, :integer
    add_column :product_upcs, :product_select_id, :integer

    ProductUpc.all.each do |product_upc|
      product_upc.selected_id = product_upc.selected_ids.first
      product_upc.product_select_id = product_upc.product_select_ids.first
      product_upc.save
    end

    remove_column :product_upcs, :selected_ids
    remove_column :product_upcs, :product_select_ids
  end
end
