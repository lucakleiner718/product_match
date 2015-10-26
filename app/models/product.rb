class Product < ActiveRecord::Base

  has_many :suggestions, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :product_id
  has_many :suggesteds, class_name: ProductSuggestion, dependent: :destroy, foreign_key: :suggested_id

  belongs_to :brand

  CLOTH_KIND = %w(
    trousers shorts shirt skirt dress jeans pants panties neckle jacket earrings bodysuit clutch belt thong
    robe chemise
  )

  scope :shopbop, -> { where source: :shopbop }
  scope :not_shopbop, -> { where("source != ?", :shopbop) }
  scope :without_upc, -> { where("upc is null OR upc = ''") }
  scope :with_upc, -> { where("upc is not null AND upc != ''") }

  # validates :upc, length: { minimum: 12, maximum: 12 }, format: { with: /\A\d+\z/ }
  # validates :ean, length: { minimum: 13, maximum: 13 }, format: { with: /\A\d+\z/ }

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

end
