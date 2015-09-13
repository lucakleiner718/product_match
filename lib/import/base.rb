class Import::Base

  def normalize_brand brand_name
    brand_name = 'Michele' if brand_name.downcase == 'michele'
    brand_name = 'Current/Elliott' if brand_name.downcase == 'current/elliott'
    brand_name
  end

end