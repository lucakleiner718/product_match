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

end