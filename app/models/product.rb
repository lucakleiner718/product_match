class Product < ActiveRecord::Base

  has_many :suggestions, class_name: ProductSuggestion

  before_save do
    if self.brand.downcase == 'current/elliott' && self.brand != 'Current/Elliott'
      self.brand = 'Current/Elliott'
    end
  end

  CLOTH_KIND = %w(trousers shorts shirt skirt dress jeans pants panties bra neckle jacket earrings bodysuit clutch)

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

  def similarity_to suggested
    params_amount = 14
    params_count = 0

    title_parts = self.title.split(/\s/).map{|el| el.downcase.gsub(/[^a-z]/i, '')}
    title_parts -= Product::CLOTH_KIND+['the']
    suggested_title_parts = suggested.title.split(/\s/).map{|el| el.downcase.gsub(/[^a-z]/i, '')}
    title_similarity = ((title_parts.size > 0 ? title_parts.select{|item| item.in?(suggested_title_parts)}.size / title_parts.size.to_f : 1) * 5).to_i

    params_count += title_similarity

    return 0 if title_similarity < 2

    if suggested.color.present? && self.color.present?
      if suggested.color.gsub(/\s/, '').downcase == self.color.gsub(/\s/, '').downcase
        params_count += 5
      else
        color_s = suggested.color.gsub(/\s/, '').downcase.split('/')
        color_p = self.color.gsub(/\s/, '').downcase.split('/')

        if color_s.size == 2 && color_p.size == 1
          if color_s.first == color_p.first || color_s.last == color_p.first
            params_count += 5
          end
        elsif color_s.size == 2 && color_p.size == 2
          if color_s.sort.join == color_p.sort.join
            params_count += 5
          end
        end
      end
    end

    if suggested.size.present? && self.size.present?
      size_s = suggested.size.gsub(/\s/, '').downcase
      size_p = self.size.gsub(/\s/, '').downcase

      if size_s == size_p || (size_s == 'small' && size_p == 's') || (size_s == 'large' && size_p == 'l') ||
          (size_s == 'medium' && size_p == 'm') || (size_s == 'x-small' && size_p == 'xs')
        params_count += 2
      elsif size_s =~ /us/i && size_s =~ /eu/
        eu_size = size_s.match(/(\d{1,2}\.?\d?)eu/i)[1]
        if size_p == eu_size
          params_count += 2
        end
      end
    else
      if suggested.size.blank? && self.size.present? && self.size.downcase == 'one size'
        params_count += 2
      end
    end

    params_count += 2 if suggested.price.present? && self.price.present? && suggested.price.to_i == self.price.to_i

    (params_count/params_amount.to_f * 100).to_i
  end

  def self.amount_by_brand_and_source brand_names
    brand_names = [brand_names] if brand_names.is_a?(String)
    sql = "
SELECT count(id), source
FROM (
  SELECT *
  FROM products
  WHERE brand IN (#{brand_names.map{|n| Product.sanitize(n)}.join(',')}) AND source != 'shopbop'
) as products
group by source

"
    Product.connection.execute(sql).to_a.inject({}){|obj, r| obj[r['source']] = r['count'].to_i; obj}
    # Product.where(brand: brand.names).not_shopbop.size

  end

end
