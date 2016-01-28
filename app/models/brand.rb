class Brand < ActiveRecord::Base

  has_many :sources, class_name: :ProductSource
  has_one :brand_stat, dependent: :destroy
  has_many :products

  scope :in_use, -> { where in_use: true }
  scope :disabled, -> { where disabled: true }

  after_save do
    if self.in_use
      if self.in_use_changed? || self.name_changed? || self.synonyms_changed?
        ProductSuggestionsGeneratorWorker.perform_at Time.zone.now.end_of_day, self.id
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
    built_stat = self.build_stat
    bs = self.brand_stat
    bs = self.build_brand_stat unless bs
    bs.attributes = built_stat
    bs.touch(:updated_at) unless bs.new_record?
    bs.save!
  end

  def build_stat
    con = Product.connection
    now = Time.zone.now

    matching_in_store = Product.where(brand_id: self.id).matching.where(in_store: true)

    shopbop_size = matching_in_store.size
    shopbop_noupc_size = matching_in_store.without_upc.size

    shopbop_matched_size = con.execute("
      SELECT count(distinct(product_id)) as amount
      FROM product_selects AS ps
      LEFT JOIN products AS pr ON pr.id=ps.product_id
      WHERE ps.decision='found' AND pr.brand_id=#{self.id}
    ").to_a.first['amount'].to_i

    shopbop_nothing_size = con.execute("
      SELECT count(distinct(product_id)) AS amount
      FROM product_selects AS ps
      LEFT JOIN products AS pr ON pr.id=ps.product_id
      WHERE ps.decision IN ('nothing', 'no-size', 'no-color', 'similar') AND pr.brand_id=#{self.id}
            AND pr.match=#{true} AND pr.in_store=#{true} AND pr.upc IS NULL
    ").to_a.first['amount'].to_i

    amounts_uniq = con.execute("
      SELECT count(total)
      FROM (
        SELECT count(distinct(upc)) as total
        FROM products
        WHERE brand_id=#{self.id} AND source NOT IN (#{Product::MATCHED_SOURCES.map{|e| Product.sanitize e}.join(',')})
          AND (upc IS NOT NULL AND upc != '')
        GROUP BY upc
      ) AS products
    ").to_a.first['count']

    amounts_sources = con.execute("
      SELECT count(distinct(upc)), source
      FROM (
        SELECT upc, source
        FROM products
        WHERE brand_id=#{self.id} AND source NOT IN (#{Product::MATCHED_SOURCES.map{|e| Product.sanitize e}.join(',')})
          AND (upc IS NOT NULL AND upc != '')
      ) AS products
      GROUP BY source
    ").to_a.inject({}){|obj, r| obj[r['source']] = r['count'].to_i; obj}

    suggestions = con.execute("
      SELECT count(distinct(product_id))
      FROM product_suggestions
      INNER JOIN products on products.id=product_suggestions.product_id
              AND source IN (#{Product::MATCHED_SOURCES.map{|e| Product.sanitize e}.join(',')})
      WHERE products.brand_id=#{self.id} AND products.match=#{true}
    ").to_a.first['count'].to_i

    suggestions_green = ProductSuggestion.select('distinct(product_id').joins(:product)
                          .where(products: { brand_id: self.id, match: true, source: Product::MATCHED_SOURCES})
                          .where(percentage: 90..100).pluck(:product_id).uniq.size
    suggestions_yellow = ProductSuggestion.select('distinct(product_id').joins(:product)
                           .where(products: { brand_id: self.id, match: true, source: Product::MATCHED_SOURCES})
                           .where(percentage: 50...90).pluck(:product_id).uniq.size

    new_match_today = matching_in_store.where('created_at >= ?', 1.day.ago(now)).size
    new_match_week = matching_in_store.where('created_at >= ?', now.monday).size


    not_matched = con.execute("
      SELECT count(distinct(products.id))
      FROM products
      LEFT JOIN product_selects ON product_selects.product_id=products.id
      INNER JOIN product_suggestions on products.id=product_suggestions.product_id AND percentage > 50
      WHERE products.brand_id=#{self.id}
            AND source IN (#{Product::MATCHED_SOURCES.map{|e| Product.sanitize e}.join(',')})
            AND match=#{true} AND (upc IS NULL OR upc='') AND product_selects.id is null
    ").to_a.first['count'].to_i

    {
      shopbop_size: shopbop_size,
      shopbop_noupc_size: shopbop_noupc_size,
      shopbop_matched_size: shopbop_matched_size,
      shopbop_nothing_size: shopbop_nothing_size,
      amounts_content: amounts_sources.to_a.map{|el| el.join(': ')}.join("<br>"),
      amounts_values: amounts_uniq,
      suggestions: suggestions,
      suggestions_green: suggestions_green,
      suggestions_yellow: suggestions_yellow,
      new_match_today: new_match_today,
      new_match_week: new_match_week,
      not_matched: not_matched
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
    self.save!

    # remove old brands
    Brand.where(id: brands_ids).destroy_all
  end

end
