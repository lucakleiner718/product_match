class Brand < ActiveRecord::Base

  has_many :sources, class_name: 'ProductSource', foreign_key: :brand_name, primary_key: :name

  scope :in_use, -> { where in_use: true }

  def synonyms_text
    self.synonyms.join(',')
  end

  def synonyms_text=synonyms_text
    self.synonyms = synonyms_text.split(',')
  end

end
