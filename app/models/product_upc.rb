class ProductUpc < ActiveRecord::Base

  belongs_to :product

  validates :product_id, presence: true, uniqueness: true
  validates :selected_ids, presence: true
  validates :product_select_ids, presence: true
  validates :upc, presence: true

  def selected
    Product.where(id: self.selected_ids)
  end

  def product_selects
    if self.product_select_ids.size > 0
      ProductSelect.where(id: self.product_select_ids)
    else
      []
    end
  end

end
