class Import::Sorel < Import::Platform::Demandware

  def baseurl; 'http://www.sorel.com'; end
  def subdir; 'Sorel_US'; end
  def lang; 'en_US'; end
  def product_id_pattern; /-([A-Z0-9_]+)\.html/; end
  def brand_name_default; 'Sorel'; end

  def perform
    [
      'womens-boots-shoe', 'mens-boots-outdoor-shoes', 'kids-boots-outdoor-shoes', 'apparel-jackets-hats',
      'sale-boots-slippers-shoes'
    ].each do |url_part|
      log url_part
      size = 60
      urls = []
      while true
        url = "#{baseurl}/#{url_part}/?sz=#{size}&start=#{urls.size}&format=page-element"
        resp = get_request(url)
        html = Nokogiri::HTML(resp.body)

        products = html.css('.product-tile .thumb-link').map{|a| a.attr('href')}.select{|l| l.present?}
        break if products.size == 0

        urls.concat(products)
      end

      spawn_products_urls(urls)
    end
  end

  def process_product(original_url)
    log "Processing url: #{original_url}"
    product_id = original_url.match(product_id_pattern)[1]

    resp = get_request("#{baseurl}/#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    canonical_url = html.css('link[rel="canonical"]').first.attr('href')
    canonical_url = "#{baseurl}#{canonical_url}" if canonical_url !~ /^http/
    if canonical_url != url
      product_id = canonical_url.match(product_id_pattern)[1]
    end

    product_id_param = product_id.gsub('_', '__')

    results = []

    product_name = html.css('#pdpMain .product-detail .product-name').first.text.strip

    category = html.css('.breadcrumb a').inject([]){|ar, el| el.text.downcase.in?(['home', 'Return to search results'.downcase]) ? '' : ar << el.text.strip; ar}.join(' > ')

    color_param = "dwvar_#{product_id_param}_color"

    images = html.css('a.thumbnail-link').map{|a| a.attr('href')}#.sub(/\/#{product_id}_\d{1,3}_m/)}
    if images.size == 0
      ppi = html.css('.product-primary-image').first
      if ppi
        if ppi.css('a').size > 0
          images = [html.css('.product-primary-image a').first.attr('href')]
        else
          images = [html.css('.product-primary-image').first.attr('data-defaultasset')]
        end
      end
    end
    # http://s7d5.scene7.com/is/image/ColumbiaSportswear2/1554681_010_m
    image = images.shift
    if image
      default_color_id = image.match(/\/#{product_id}_([^\_]+)_/) && $1
      default_color_id = image.match(/\/#{product_id.match(/^([^\_]+)/)}_([^\_]+)_/) && $1 unless default_color_id
    end

    data = get_json product_id
    return false unless data
    data.each do |k, v|
      upc = v['id']
      price = v['pricing']['standard']
      price_sale = v['pricing']['sale']
      if price == 0 && price_sale.present? && price_sale > 0
        price = price_sale
        price_sale = nil
      end
      color = v['attributes']['variationColor'].strip
      size = v['attributes']['variationSize']
      color_id = k.split('|').inject({}){|obj, el| a = el.split('-'); obj[a[0]] = a[1]; obj}['variationColor']
      color_url = "#{url}?#{color_param}=#{color_id}"

      image_url = nil
      image_url = image.sub(/\/#{product_id}_#{default_color_id}_/, "/#{product_id}_#{color_id}_") if image

      results << {
        title: product_name,
        category: category,
        price: price,
        price_sale: price_sale,
        color: color,
        size: size,
        upc: upc,
        url: color_url,
        image: image_url,
        style_code: product_id,
        brand: brand_name_default,
      }
    end

    prepare_items(results)
    process_results_batch(results)
  end

end