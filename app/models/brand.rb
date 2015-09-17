class Brand < ActiveRecord::Base

  has_many :sources, class_name: 'ProductSource', foreign_key: :brand_name, primary_key: :name

  scope :in_use, -> { where in_use: true }

  after_commit on: [:create, :update] do
    if self.in_use && self.in_use_changed?
      ProductSuggestionsGeneratorWorker.perform_async brand: self.name
    end
  end

  validates :name, uniqueness: true

  def synonyms_text
    self.synonyms.join(',')
  end

  def synonyms_text=synonyms_text
    self.synonyms = synonyms_text.split(',')
  end

  def self.names_in_use
    self.in_use.pluck(:name, :synonyms).flatten
  end

  def names
    [self.name, self.synonyms].flatten
  end

  def self.get_by_name name
    self.where("name = ? OR synonyms @> ?", name, "{#{name}}").first
  end

end
