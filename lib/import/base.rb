require 'faraday_middleware'

class Import::Base

  def normalize_brand brand_name
    replacements = ['Michele', 'Current/Elliott', 'Alice + Olivia']
    replacements.each do |replacement|
      brand_name = replacement if brand_name.to_s.downcase == replacement.downcase
    end
    brand_name
  end

  def normalize_title title, brand
    title.sub(/#{Regexp.quote brand.to_s}\s?/i, '').sub(/^(,|-)*/, '').strip.gsub('&#39;', '\'')
  end

  def normalize_retailer retailer
    retailer
  end

  def source
    self.class.name.match(/\:\:(.*)/)[1].downcase
  end

  def csv_chunk_size
    1_000
  end

  def convert_brand items
    brands_names = items.map{|it| it[:brand].to_s}.uniq.select{|it| it.present?}
    exists_brands = Brand.where("name IN (?) OR synonyms && ?", brands_names, "{#{brands_names.map{|e| e}.join(',')}}")
    brands = brands_names.map do |brand_name|
      brand = exists_brands.select{|b| b.name == brand_name || brand_name.in?(b.synonyms)}.first
      # brand = Brand.get_by_name(brand_name)
      brand = Brand.create(name: brand_name) unless brand
      brand
    end
    items.map do |item|
      br = brands.select{|b| b.name == item[:brand] || item[:brand].in?(b.synonyms) }.first
      item[:brand_id] = br.try(:id)
      item.delete :brand
    end
    items
  end

  def get_request url
    Curl.get(url) do |http|
      http.follow_location = true
    end
    # con = Faraday.new(url) do |b|
    #   b.use FaradayMiddleware::FollowRedirects
    #   b.adapter :net_http
    # end
    # con.get
  end

end