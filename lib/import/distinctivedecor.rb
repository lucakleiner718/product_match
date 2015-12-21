class Import::Distinctivedecor < Import::Base

  # platform = aabaco
  # platform-pattern - assets are under lib.store.yahoo.net domain

  def baseurl; 'http://www.distinctive-decor.com'; end

  def perform
    urls = []
    page_no = 1
    while true
      url = "http://search.distinctive-decor.com/mod_search/index.php?keywords=swell&filters%5Bbrand%5D%5B%5D=S%27well&filters%5Bbrand%5D%5B%5D=Swell&page=#{page_no}"
      resp = get_request(url)
      html = Nokogiri::HTML(resp.body)
      links = html.css('.pdsResults .pdsGridWrap .pdsImg a').map{|a| a.attr('href')}
      break if links.size == 0

      urls += links.map{|url| url =~ /^http/ ? url : "http://search.distinctive-decor.com/mod_search/#{url}" }
      page_no += 1
    end
    spawn_products_urls(urls, false)
  end

  def process_product(original_url)
    original_url = original_url.sub(/configId=\d+&/, '&')
    log "Processing url: #{original_url}"
    resp = get_request(original_url)
    return false unless resp.success?
    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    results = []

    product_name = html.css('#itemName').first.text
    style_code = html.css('#itemCode').first.text.sub(/^# /, '')
    price = html.css('.regPriceWOS b').first.text.sub(/^\$/, '')
    price_currency = 'USD'
    image = html.css('.fp-image-main a').first.attr('href')
    tab_data = html.css('.tabContent .text div:contains("UPC")').first

    return false unless tab_data

    tab_data_items = tab_data.text.split('|').each_with_object({}){|el, obj| k,v = el.strip.split(':'); obj[k] = v.strip}
    brand = tab_data_items.values.first
    upc = tab_data_items['UPC']

    results << {
      title: product_name,
      brand: brand,
      price: price,
      price_currency: price_currency,
      upc: upc,
      url: url,
      image: image,
      style_code: style_code,
    }

    prepare_items(results)
    process_results_batch(results)
  end
end
