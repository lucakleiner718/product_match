class Import::Sunglasshut < Import::Base

  # platform = wcsstore

  def baseurl; 'http://www.sunglasshut.com'; end
  def url_prefix_country; 'us'; end

  def perform
    page = get_request('sunglasses-trends/sunglass-brands')
    html = Nokogiri::HTML(page.body)

    urls = []
    brands_links = html.css('.exp-all-brands a.exp-all-brands-link').map{|a| a.attr('href')}
    brands_links.each do |brand_link|
      urls += LoadLinks.new(brand_link, self).grab
    end

    urls.each {|u| ProcessImportUrlWorker.perform_async self.class.name, 'process_url', u }
    log "spawned #{urls.size} urls"
  end

  def process_url url
    url = URI.encode(url)
    log "Processing url: #{url}"
    resp = get_request url
    return false if resp.response_code != 200

    page = resp.body
    html = Nokogiri::HTML(page)

    brand = html.css('span[itemprop="brand"] h1').first.text
    style_code, product_name = html.css('div[itemref~="pdp-description"] h2').first.text.split(' ', 2)
    size = html.css('#measurements div p').map(&:text).join(' / ')
    price = html.css('.sale-price').first.text

    frame_color = page.match(/frame_color:"([^"]+)".toLowerCase/) && $1
    lens_color = page.match(/lens_color:"([^"]+)".toLowerCase/) && $1
    lens_material = page.match(/lens_material:"([^"]+)".toLowerCase/) && $1
    category = page.match(/category:"([^"]+)".toLowerCase/) && $1

    gender = nil
    if category.downcase == 'men'
      gender = 'Male'
      category = nil
    end
    color = [frame_color,lens_color].compact.map(&:strip).join(' / ')
    upc = url.match(/\/(\d{12,14})$/)[1]
    return false unless upc

    image = html.css('.product_images .product .pic').first.attr('src')

    results = [{
      title: product_name,
      category: category,
      price: price,
      color: color,
      size: size,
      upc: upc,
      url: url,
      image: image,
      source_id: upc,
      style_code: style_code,
      gender: gender,
      brand: brand,
      material: lens_material,
    }]

    prepare_items(results)
    process_results_batch(results)
    results
  end

  def build_url url
    if url !~ /^http/
      url_parts = []
      url_parts << baseurl
      if url[0] != '/'
        url_parts << url_prefix_country
      end
      url_parts << url

      url_parts.compact.join('/')
    else
      super url
    end
  end

  class LoadLinks
    def initialize start_url, parent
      @urls = []
      @start_url = start_url
      @parent = parent
    end

    delegate :log, :get_request, to: :parent

    def grab
      load_category @start_url
      @urls
    end

    private

    attr_reader :parent

    def load_category url
      log "[#{@urls.size}] #{url}"

      resp = get_request(url)
      html = Nokogiri::HTML(resp.body)

      links = html.css('.item.plp a.main-img').map{|a| a.attr('href')}
      return if links.size == 0
      @urls += links

      paginate_next = html.css('.pagination .pager:not(.disabled):contains("Next")').first
      if paginate_next
        load_category paginate_next.attr('href')
      end
    end
  end
end
