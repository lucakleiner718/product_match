class BrandDuplicate < ActiveRecord::Base

  belongs_to :target, class_name: 'Brand', foreign_key: :target_brand_id
  belongs_to :duplicate, class_name: 'Brand', foreign_key: :duplicate_brand_id

  validates :target_brand_id, presence: true
  validates :duplicate_brand_id, presence: true

  scope :actual, -> { where(processed: nil) }

end
