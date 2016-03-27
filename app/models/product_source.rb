class ProductSource < ActiveRecord::Base

  SOURCES = {
    'Amazon Publisher API' => :amazon_ad_api,
    'CJ.com' => :cj,
    'Popshops (brand)' => :popshops, 'Popshops (merchant)' => :popshops_merchant,
    'Linksynergy' => :linksynergy, 'Shopbop' => :shopbop, 'Eastdane' => :eastdane,
    'Website' => :website
  }

  validates :source_name, presence: true
  validates :source_id, presence: true

  validates_uniqueness_of :source_id, scope: :source_name

  scope :outdated, -> {
    where('period > 0').where("collected_at < to_timestamp(#{Time.now.utc.to_i} - period) OR collected_at IS NULL")
  }

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
      self.source_id = self.source_id.strip.gsub(/,$/, '')
    end
  end

  after_commit on: :create do
    BrandCollectDataWorker.perform_async self.id if self.period > 0
  end

  belongs_to :brand

  PERIODS = [
    ['Every hour', 1.0/24], ['Every 3 hours', 1.0/8], ['Every 6 hours', 1.0/4],
    ['Every 12 hours', 0.5], ['Every day', 1], ['Every week', 7], ['Every month', 30], ['Manual', 0]
  ].map{|el| el[1] = (el[1] * 1.day).to_i; el}

  def period_days
    self.period / 1.day.to_i if self.period && self.period > 0
  end

  def period_hours
    self.period / 1.hour.to_i if self.period && self.period > 0
  end

  def products
    search = Product.all
    search = search.where(brand_id: self.brand_id) if self.brand_id.present?
    search = search.where(source: self.source_name) if self.source_name.present?
    search
  end

  def up_to_date?
    return false unless self.collected_at
    Time.zone.now - self.collected_at < self.period
  end

end
