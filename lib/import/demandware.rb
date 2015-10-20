class Import::Demandware < Import::Base

  def product_id_pattern; /\/([a-z0-9\-\.\+]+)\.html/i; end
  def lang; 'default'; end
  def url_prefix_country; nil; end
  def url_prefix_lang; nil; end
  def brand_name_default; nil; end

  def self.perform
    instance = self.new
    instance.perform
  end

  def process_results results, brand_name=nil
    brand = Brand.get_by_name(brand_name)
    if !brand && brand_name_default
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name if brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      product = Product.where(source: source, style_code: row[:style_code], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id if brand
      product.save
    end
  end

  def process_results_source_id results, brand_name=nil
    brand = Brand.get_by_name(brand_name)
    if !brand && brand_name_default
      brand = Brand.where(name: brand_name_default).first
      brand.synonyms.push brand_name if brand_name
      brand.save if brand.changed?
    end

    results.each do |row|
      product = Product.where(source: source, source_id: row[:source_id], color: row[:color], size: row[:size]).first_or_initialize
      product.attributes = row
      product.brand_id = brand.id if brand
      product.save
    end
  end

  def get_json product_id
    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/default/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    JSON.parse(data_resp.body.strip)
  end

end