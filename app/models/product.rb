class Product < ActiveRecord::Base

  before_save do
    if self.brand.downcase == 'current/elliott' && self.brand != 'Current/Elliott'
      self.brand = 'Current/Elliott'
    end
  end

  scope :shopbop, -> { where source: :shopbop }
  scope :not_shopbop, -> { where('source != ?', :shopbop) }


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
    title_parts -= ['shorts', 'skirt', 'dress', 'jeans', 'pants', 'panties', 'the']
    suggested_title_parts = suggested.title.split(/\s/).map{|el| el.downcase.gsub(/[^a-z]/i, '')}
    title_similarity = (title_parts.select{|item| item.in?(suggested_title_parts)}.size / title_parts.size.to_f * 5).to_i

    params_count += title_similarity

    return 0 if title_similarity < 2

    params_count += 5 if suggested.color.present? && self.color.present? && suggested.color.gsub(/\s/, '').downcase == self.color.gsub(/\s/, '').downcase

    if suggested.size.present? && self.size.present?
      size_s = suggested.size.gsub(/\s/, '').downcase
      size_p = self.size.gsub(/\s/, '').downcase
      if size_s == size_p || (size_s == 'small' && size_p == 's') || (size_s == 'large' && size_p == 'l') ||
          (size_s == 'medium' && size_p == 'm') || (size_s == 'x-small' && size_p == 'xs')
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
