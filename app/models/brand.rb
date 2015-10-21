class Brand < ActiveRecord::Base

  has_many :sources, class_name: 'ProductSource'
  has_one :brand_stat
  has_many :products

  scope :in_use, -> { where in_use: true }

  after_save do
    if self.in_use
      if self.in_use_changed? || self.name_changed? || self.synonyms_changed?
        ProductSuggestionsGeneratorWorker.perform_at Time.now.end_of_day, self.id
      end
    end
  end

  before_save do
    self.synonyms = self.synonyms.select{|t| t.present?}.uniq
  end

  validates :name, uniqueness: true

  def synonyms_text
    self.synonyms.join(',')
  end

  def synonyms_text=synonyms_text
    self.synonyms = synonyms_text.split(',').map(&:strip)
  end

  def names
    [self.name, self.synonyms].flatten
  end

  def self.get_by_name name
    return false if !name || name.blank?
    self.where("lower(name) = lower(?) OR synonyms @> ? OR synonyms @> ?", name, "{#{name}}", "{#{name.downcase}}").first
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
      SELECT count(distinct(product_id)) as amount
      FROM product_selects AS ps
      LEFT JOIN products AS pr ON pr.id=ps.product_id
      WHERE ps.decision='found' AND pr.brand_id=#{49}
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

  def merge_with! brands_ids
    # protect from delete main brand
    brands_ids = brands_ids.map(&:to_i) - [self.id]

    # first update products with new brand
    Product.where(brand_id: brands_ids).update_all(brand_id: self.id)

    # update product sources with new brand
    ProductSource.where(brand_id: brands_ids).update_all(brand_id: self.id)

    # find all names for brands and add them as synonyms
    names = Brand.where(id: brands_ids).pluck(:name, :synonyms).flatten
    self.synonyms += names
    self.synonyms = self.synonyms.uniq - [self.name]
    self.save

    # remove old brands
    Brand.where(id: brands_ids).destroy_all
  end

end
