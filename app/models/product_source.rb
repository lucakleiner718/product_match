class ProductSource < ActiveRecord::Base

  validates :source_name, presence: true
  validates :source_id, presence: true

  validates_uniqueness_of :source_id, scope: :source_name

  before_validation do
    if self.name_changed? && self.name.blank?
      if self.source_name == 'popshops'
        info = Import::Popshops.get_info(self.source_id)
        if info[:count] > 0
          # ...
        end

        self.name = info[:name] if info[:name]
      end
    end
  end

end
