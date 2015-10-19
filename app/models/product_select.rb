class ProductSelect < ActiveRecord::Base

  belongs_to :product
  belongs_to :selected, class_name: 'Product'
  belongs_to :user

  validates :user, presence: true

  scope :found, -> { where decision: :found }

end
