class Product < ActiveRecord::Base

  has_many :suggestions, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :product_id
  has_many :suggesteds, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :suggested_id
  has_one :product_upc, dependent: :destroy
  has_many :product_selects, dependent: :destroy

  belongs_to :brand

  MATCHED_SOURCES = %w(shopbop eastdane)

  scope :matching, -> { where source: Product::MATCHED_SOURCES}
  scope :not_matching, -> { where.not(source: Product::MATCHED_SOURCES) }
  scope :shopbop, -> { matching }
  scope :not_shopbop, -> { not_matching }
  scope :without_upc, -> { where(upc: [nil, '']) }
  scope :with_upc, -> { where.not(upc: [nil, '']) }
  scope :in_stock, -> { where(in_store: true) }
  scope :with_image, -> { where.not(image: nil) }
  scope :by_title, -> (str) { where("to_tsvector(products.title) @@ to_tsquery('#{str}')") }
  scope :title_contains, -> (words) {
    query_words = words.map do |el|
      el.split(' ').size > 1 ? "(#{el.split(' ').join(' & ')})" : el
    end
    synonyms_query = "to_tsvector(products.title) @@ to_tsquery('#{query_words.join(' | ')}')"
    where(synonyms_query)
  }
  scope :title_like, -> (words) {
    where(words.map{|el| "products.title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))
  }

  # validates :upc, format: { with: /\A\d+\z/ }, allow_nil: true

  after_update do
    if self.source.in?(Product::MATCHED_SOURCES) && self.upc_changed? && self.upc_was.nil?
      ProductSuggestion.where(product_id: self.id).delete_all
    end
  end

  after_commit :image_local_update, on: :create

  after_destroy do
    images = [self.image_local] + self.additional_images_local
    images.compact.each do |image|
      DeleteProductImage.perform_async(image)
    end
  end

  # validates :upc, length: { minimum: 8, maximum: 14 }, format: { with: /\A\d+\z/ }

  def self.export_to_csv source: 'popshops', brand_id: nil, category: nil
    products = Product.where(source: source, brand_id: brand_id)
    products = products.where(category: category) if category

    csv_string = CSV.generate do |csv|
      csv << Product.column_names.select{|r| !r.in?(['id', 'created_at', 'updated_at'])}
      products.each do |product|
        csv << product.attributes.select{|k,v| !k.in?(['id', 'created_at', 'updated_at'])}.values
      end
    end

    File.write "tmp/#{source}-#{brand_id}#{"-#{category.gsub(/\'/, '').gsub(/\s/, '-')}" if category}-#{Time.now.to_i}.csv", csv_string
  end

  def upc_patterns
    @upc_patterns ||= begin
      same_products_upcs = Product.where(style_code: self.style_code, source: self.source, color: self.color)
                             .with_upc.pluck(:upc)
      same_products_upcs.map{|upc| upc[0,upc.size-3]}.uniq
    end
  end

  def display_price
    if self.price.present?
      if self.price_sale.present? && self.price_sale < self.price
        "$#{self.price_sale_m} ($#{self.price_m})"
      else
        "$#{self.price_m}"
      end
    else
      'N/A'
    end
  end

  def cancel_upc
    ActiveRecord::Base.transaction do
      self.update! match: true, upc: nil

      product_upc = ProductUpc.find_by!(product_id: self.id)
      if product_upc
        product_upc.product_selects.delete_all
        product_upc.destroy!
        
        # build suggestions
        ProductSuggestionsWorker.perform_async(self.id)
      end
    end
  end

  def price_m(exchange=true)
    return nil unless self.price
    resp = Money.new(self.price.to_f*100, self.price_currency || 'USD')
    resp = resp.exchange_to("USD") if exchange
    resp
  end

  def price_sale_m(exchange=true)
    return nil unless self.price_sale
    resp = Money.new(self.price_sale.to_f*100, self.price_currency || 'USD')
    resp = resp.exchange_to("USD") if exchange
    resp
  end

  private

  def image_local_update
    ImageLocalWorker.perform_async(self.id) if Rails.env.production?
  end
end
