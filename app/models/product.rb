class Product < ActiveRecord::Base

  has_many :suggestions, class_name: ProductSuggestion

  before_save do
    if self.brand.downcase == 'current/elliott' && self.brand != 'Current/Elliott'
      self.brand = 'Current/Elliott'
    end
  end

  CLOTH_KIND = %w(
    trousers shorts shirt skirt dress jeans pants panties neckle jacket earrings bodysuit clutch belt thong
    robe chemise
  )

  scope :shopbop, -> { where source: :shopbop }
  scope :not_shopbop, -> { where("source != ?", :shopbop) }
  scope :without_upc, -> { where("upc is null OR upc = ''") }
  scope :with_upc, -> { where("upc is not null AND upc != ''") }

  def self.export_to_csv source: 'popshops', brand: 'Current/Elliott', category: nil
    products = Product.where(source: source, brand: brand)
    products = products.where(category: category) if category

    csv_string = CSV.generate do |csv|
      csv << Product.column_names.select{|r| !r.in?(['id', 'created_at', 'updated_at'])}
      products.each do |product|
        csv << product.attributes.select{|k,v| !k.in?(['id', 'created_at', 'updated_at'])}.values
      end
    end

    File.write "tmp/#{source}-#{brand.gsub('/', '-')}#{"-#{category.gsub(/\'/, '').gsub(/\s/, '-')}" if category}-#{Time.now.to_i}.csv", csv_string
  end

  def self.amount_by_brand_and_source brand_names
    brand_names = [brand_names] if brand_names.is_a?(String)
    sql = "
      SELECT count(id), source
      FROM (
        SELECT *
        FROM products
        WHERE brand IN (#{brand_names.map{|n| Product.sanitize(n)}.join(',')}) AND source != 'shopbop' AND upc IS NOT NULL AND upc != ''
      ) AS products
      GROUP BY source
    "
    Product.connection.execute(sql).to_a.inject({}){|obj, r| obj[r['source']] = r['count'].to_i; obj}
  end

end
