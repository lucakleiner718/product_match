class ProductSource < ActiveRecord::Base

  validates :source_name, presence: true
  validates :source_id, presence: true

  validates_uniqueness_of :source_id, scope: :source_name

  before_save do
    if self.name.blank?
      if self.source_name == 'popshops'
        info = Import::Popshops.get_info(self.source_id)
        if info[:count] > 0
          # ...
        end

        self.name = info[:name] if info[:name]
      end
    end

    if self.source_id.present? && self.source_id_changed?
      self.source_id = self.source_id.gsub(/\s/, '').strip.gsub(/^,/, '').gsub(/,$/, '')
    end
  end

  after_commit on: :create do
    BrandCollectDataWorker.perform_async self.id
  end

  belongs_to :brand

end
