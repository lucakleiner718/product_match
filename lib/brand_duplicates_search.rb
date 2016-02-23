class BrandDuplicatesSearch
  def initialize

  end

  def generate
    brands = Brand.in_use
    brands.each do |brand|
      create_duplicates(brand)
    end
    find_brand_by_upc
  end

  private

  attr_reader :brand

  def create_duplicates(brand)
    brand_name = brand.name.downcase
    ids = other_brands.select do |(_id, name)|
      name.downcase == brand_name || name.gsub(/[^a-z0-9]/i, '') == brand_name.gsub(/[^a-z0-9]/i, '') ||
        brand.synonyms.find{|syn| name.downcase == syn.downcase || name.gsub(/[^a-z0-9]/i, '') == syn.gsub(/[^a-z0-9]/i, '')}
    end.map(&:first)
    ids.each do |duplicate_id|
      next if brands_duplicates.include?([brand.id, duplicate_id])
      BrandDuplicate.where(target: brand, duplicate: duplicate_id).create!
    end
  end

  def other_brands
    @other_brands ||= Brand.where(in_use: false).where.not(name: nil).pluck(:id, :name)
  end

  def brands_duplicates
    @brands_duplicates ||= BrandDuplicate.pluck(:target_brand_id, :duplicate_brand_id)
  end

  def find_brand_by_upc
    brands = Brand.connection.execute("
      SELECT b1.id as brand1, b2.id as brand2
      FROM brands as b1
      LEFT JOIN products p1 on p1.brand_id=b1.id
      LEFT JOIN products p2 on p2.upc=p1.upc
      LEFT JOIN brands as b2 on b2.id=p2.brand_id
      WHERE b1.in_use=true AND p1.upc is not null AND b1.id != b2.id AND b2.in_use=false
    ").to_a

    brands.uniq.each do |row|
      target_id = row['brand1']
      duplicate_id = row['brand2']
      next if brands_duplicates.include?([target_id, duplicate_id])
      BrandDuplicate.where(target_brand_id: target_id, duplicate_brand_id: duplicate_id).first_or_create!
    end
  end
end