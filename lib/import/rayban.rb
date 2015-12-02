class Import::Rayban < Import::Base

  def baseurl; 'http://www.ray-ban.com'; end
  def brand; 'Ray-Ban'; end
  def country; 'usa'; end

  def perform
    urls = []

    [
      'sunglasses/men-s/plp', 'sunglasses/women-s/plp', 'sunglasses/junior/plp',
      'eyeglasses/men-s/plp', 'eyeglasses/women-s/plp', 'eyeglasses/junior/plp'
    ].each do |cat_link|
      urls += LoadLinks.new("#{country}/#{cat_link}", self).grab
    end

    urls = process_products_urls(urls)

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

    product_name = html.css('#wcs-productdescval').first.text
    category = nil
    price = html.css('#wcs-productprice').first.text
    color = [
      html.css('#wcs-lenstreatmentcolor').first.try(:text),
      html.css('#wcs-framematerial').first.try(:text),
      html.css('#schemaOrgColor').first.try(:text)
    ].compact.map(&:strip).join(' / ')
    size = html.css('#wcs-framesize').first.text
    upc = html.css('#schemaOrgGtin13').first.text

    return false unless upc

    image = html.css('#wcs-imageDisplay').first.attr('src')
    source_id = html.css('#schemaOrgSKU').first.text
    url_data = url.match(/\/([^\/%]+)%20([A-Z]+)%20([^-]+)-/i)
    # style_code = html.css('#schemaOrgModel').first.text
    style_code = url_data[1]
    # begin
      gender = {'male' => 'Male', 'female' => 'Female', 'men' => 'Male'}[url_data[2].downcase]
    # rescue => e
    #   binding.pry
    # end

    results = [{
      title: product_name,
      category: category,
      price: price,
      color: color,
      size: size,
      upc: upc,
      url: url,
      image: image,
      source_id: source_id,
      style_code: style_code,
      gender: gender,
      brand: brand
    }]

    prepare_items(results)
    process_results_batch(results)
    results
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

      links = html.css('.plp-container .categories > a').map{|a| a.attr('href')}
      return if links.size == 0
      @urls += links

      html.css('.categories a.viewmorelink, #loadMoreHijax').each do |viewmore_link|
        load_category viewmore_link.attr('href')
      end
    end

  end

end