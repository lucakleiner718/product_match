class Product < ActiveRecord::Base

  has_many :suggestions, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :product_id
  has_many :suggesteds, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :suggested_id
  has_one :product_upc, dependent: :destroy
  has_many :product_selects, dependent: :destroy

  belongs_to :brand

  MATCHED_SOURCES = %w(shopbop eastdane)

  KINDS = {
    pants: ['trousers', 'pants', 'panties', 'jeans', 'chinos', 'leggings'],
    shoes: [
      'boot', 'boots', 'bootie', 'booties', 'sneaker', 'sneakers', 'sandal', 'sandals', 'mule', 'oxford', 'oxfords',
      'flats', 'wedge', 'plimsole', 'espadrilles'
    ],
    accessories: [
      'belt', 'neckle', 'necklace', 'earrings', 'bracelet', 'scarf', 'earring set', 'ring'
    ],
    underware: [
      'chemise', 'thong', 'bra', 'bralette', 'bikini top', 'bikini bottoms', 'bottoms', 'lace',
    ],
    bags: ['clutch', 'bag', 'backpack'],
    dresses: ['dress', 'robe', 'gown', 'romper', 'jumpsuit', 'slipdress', 'minidress'],
    jacket: ['jacket', 'parka', 'vest'],
    top: [
      'top', 'tee', 'tank', 'blouse', 'shirt', 'cami', 'camisole', 'tee', 'polo', 'tunic',
      'pullover'
    ],
    sweater: ['sweater', 'sweatshirt', 'sleepshirt', 'vee'],


    skirt: ['skirt', 'miniskirt'],
    coat: ['coat', 'peacoat'],
    slip: ['slip'],
    cardigan: ['cardigan', 'poncho'],
    shorts: ['shorts'],
    bodysuit: ['bodysuit'],
    turtleneck: ['turtleneck']
  }

  scope :matching, -> { where source: Product::MATCHED_SOURCES}
  scope :not_matching, -> { where.not(source: Product::MATCHED_SOURCES) }
  scope :shopbop, -> { matching }
  scope :not_shopbop, -> { not_matching }
  scope :without_upc, -> { where(upc: [nil, '']) }
  scope :with_upc, -> { where.not(upc: [nil, '']) }

  after_update do
    if self.source.in?(Product::MATCHED_SOURCES) && self.upc_changed? && self.upc_was.nil?
      ProductSuggestion.where(product_id: self.id).delete_all
    end
  end

  after_commit :image_local_update, on: :create

  after_destroy do
    images = [self.image_local] + self.additional_images_local
    images.compact.each do |image|
      DeleteProductImage.perform_async image
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
        "#{self.price_sale} (#{self.price})"
      else
        self.price
      end
    else
      'N/A'
    end
  end

  private

  def image_local_update
    ImageLocalWorker.perform_async self.id if Rails.env.production?
  end
end
