class ProductSelect < ActiveRecord::Base

  belongs_to :product
  belongs_to :selected, class_name: 'Product'

end
