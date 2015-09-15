class Import::Base

  def normalize_brand brand_name
    brand_name = 'Michele' if brand_name.downcase == 'michele'
    brand_name = 'Current/Elliott' if brand_name.downcase == 'current/elliott'
    brand_name
  end

  def normalize_title title, brand
    title.sub(/#{Regexp.quote brand}\s?/i, '').sub(/^,/, '').strip#.split(',').select{|el| el.present?}.first
      # .sub(/#{brand}\s?/i, '').split(',').first.gsub('&#39;', '\'')
  end

  def source
    self.class.name.match(/\:\:(.*)/)[1].downcase
  end

  def csv_chunk_size
    1_000
  end

end