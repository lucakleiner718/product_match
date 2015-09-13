class ProductSource < ActiveRecord::Base

  validates :name, presence: true
  validates :source_name, presence: true
  validates :source_id, presence: true

end
