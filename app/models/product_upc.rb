class ProductUpc < ActiveRecord::Base

  belongs_to :product

  validates :product_id, presence: true, uniqueness: true
  validates :selected_ids, presence: true
  validates :product_select_ids, presence: true
  validates :upc, presence: true

end
