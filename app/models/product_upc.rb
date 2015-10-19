class ProductUpc < ActiveRecord::Base

  belongs_to :product
  belongs_to :selected, class_name: 'Product'
  belongs_to :product_select

  validates :product_id, presence: true
  validates :selected_id, presence: true
  validates :product_select_id, presence: true
  validates :upc, presence: true

end
