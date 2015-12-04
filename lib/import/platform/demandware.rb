class Import::Platform::Demandware < Import::Base

  def product_id_pattern; /\/([a-z0-9\-\.\+]+)\.html/i; end
  def lang; 'default'; end
  def url_prefix_country; nil; end
  def url_prefix_lang; nil; end
  def brand_name_default; nil; end

  def get_json product_id
    data_url = "#{baseurl}/on/demandware.store/Sites-#{subdir}-Site/#{lang}/Product-GetVariants?pid=#{product_id}&format=json"
    data_resp = get_request(data_url)
    body = data_resp.body.strip
    return false if body.blank?

    if body !~ /\A\{\s?"/
      body = body.gsub(/inStockDate\:\s\"[^"]+\",/, '').gsub(/(['"])?([a-zA-Z0-9_]+)(['"])?:/, '"\2":')
    end

    begin
      json = JSON.parse(body)
    rescue JSON::ParserError => e
      return false
    end
    json
  end

  def build_url url
    if url !~ /^http/
      url_parts = []
      url_parts << baseurl
      if url[0] != '/'
        url_parts << url_prefix_country
        url_parts << url_prefix_lang
      end
      url_parts << url

      url_parts.compact.join('/')
    else
      super url
    end
  end

end