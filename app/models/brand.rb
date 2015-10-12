class Brand < ActiveRecord::Base

  has_many :sources, class_name: 'ProductSource'
  has_one :brand_stat
  has_many :products

  scope :in_use, -> { where in_use: true }

  after_save do
    if self.in_use
      if self.in_use_changed? || self.name_changed? || self.synonyms_changed?
        ProductSuggestionsGeneratorWorker.perform_async brand_id: self.id
      end
    end
  end

  validates :name, uniqueness: true

  def synonyms_text
    self.synonyms.join(',')
  end

  def synonyms_text=synonyms_text
    self.synonyms = synonyms_text.split(',')
  end

  def names
    [self.name, self.synonyms].flatten
  end

  def self.get_by_name name
    self.where("name = ? OR synonyms @> ?", name, "{#{name}}").first
  end

  def stat
    if !self.brand_stat || self.brand_stat.updated_at < 1.day.ago
      BrandStatWorker.perform_async self.id
    end

    self.brand_stat
  end

  def update_stat
    s = self.build_stat
    self.build_brand_stat unless self.brand_stat
    self.brand_stat.attributes = s
    self.brand_stat.save
  end

  def build_stat
    shopbop_matched_size = ProductSelect.connection.execute("
      SELECT count(product_id) as amount
      FROM product_selects AS ps
      LEFT JOIN products AS pr ON pr.id=ps.product_id
      WHERE ps.decision='found' AND pr.brand_id=#{Brand.sanitize self.id}
    ").to_a.first['amount'].to_i

    # shopbop_matched_size
    amounts = Product.amount_by_brand_and_source(self.id)
    {
      shopbop_size: Product.where(brand_id: self.id).shopbop.size,
      shopbop_noupc_size: Product.where(brand_id: self.id).shopbop.where("upc is null OR upc = ''").size,
      shopbop_matched_size: shopbop_matched_size,
      amounts_content: amounts.to_a.map{|el| el.join(': ')}.join("<br>"),
      amounts_values: amounts.values.sum,
      suggestions: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand_id: self.id}).pluck(:product_id).uniq.size,
      suggestions_green: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand_id: self.id}).where(percentage: 100).pluck(:product_id).uniq.size,
      suggestions_yellow: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand_id: self.id}).where('percentage < 100 AND percentage > 50').pluck(:product_id).uniq.size
    }
  end

end
