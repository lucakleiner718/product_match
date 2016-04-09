class AddIndexToCreatedAtProducts < ActiveRecord::Migration
  def change
    add_index :products, :created_at,
      where: "source IN ('shopbop', 'eastdane') AND (upc IS NULL OR upc='')",
      order: :created_at
  end
end
