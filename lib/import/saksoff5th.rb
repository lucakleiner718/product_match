class Import::Saksoff5th < Import::Platform::Demandware

  def baseurl; 'http://www.saksoff5th.com'; end
  def subdir; 'SaksOff5th'; end
  def product_id_pattern; /(\d+)\.html/i; end

  def perform
    resp = get_request(internal_url("Designers-JsonData"))
    json = JSON.parse(resp.body)
    designers = json['All Designers'].map{|el| el['title']}
    designers.each do |designer|
      designer_url = "search?cat=Designer&prefn1=brand&prefv1=#{designer}&designerName=#{designer}&pageSource=DesignersPage"
      spawn_url('category', build_url(designer_url))
    end
  end

  def process_category(category_url)
    page_size = 110
    page_no = 1
    urls = []
    while true
      category_url = "#{category_url}&sz=#{page_size}&start=#{(page_no-1)*page_size}&srule="
      log category_url
      resp = get_request(category_url)
      html = Nokogiri::HTML(resp.body)
      products = html.css('.grid-tile .product-tile a.thumb-link').map{|a| a.attr('href')}
      break if products.size == 0 || (products & urls).size == products.size

      urls += products
      break if products.size < page_size
      page_no += 1
    end

    spawn_products_urls(urls)
  end

  def process_product(original_url)
    product_id = original_url.match(product_id_pattern)[1]
    resp = get_request("#{product_id}.html")
    return false if resp.response_code != 200

    url = resp.effective_url

    page = resp.body
    html = Nokogiri::HTML(page)

    colors = []
    html.css('.swatches.Color .emptyswatch a').each do |a|
      colors << {
        title: a.attr('title'),
        image: a.attr('data-lgimg').match(/'url':'([^']+)'/) && $1,
        # pattern: a.attr('href').match(/dwvar_#{product_id}_color=([^&]+)/) && $1
      }
    end

    sizes = []
    html.css('.swatches.size .emptyswatch a').each do |a|
      sizes << {
        title: a.attr('title'),
        # pattern: a.attr('href').match(/dwvar_#{product_id}_size=([^&]+)/) && $1
        # pattern: a.attr('title')
      }
    end

    results = []

    product_name = html.css('#product-content .pdt-short-desc').first.text.strip
    price = html.css('.product-price .price-standard span').first.text.strip.gsub(/[^0-9\.]/, '')
    price_sale = html.css('.product-price .price-sales').first.text.strip.gsub(/[^0-9\.]/, '')
    price_currency = 'USD'
    brand = html.css('h1.product-name span').first.text.strip

    colors.each do |color|
      sizes.each do |size|
        resp = get_request(internal_url('Product-Variation', pid: product_id,
            "dwvar_#{product_id}_size": size[:title], "dwvar_#{product_id}_color": color[:title],
            format: :ajax
        ))
        html = Nokogiri::HTML(resp.body)
        upc = html.css('#pid').first.attr('value')

        next if upc.to_s == product_id.to_s

        results << {
          title: product_name,
          price: price,
          price_sale: price_sale,
          price_currency: price_currency,
          color: color[:title],
          size: size[:title],
          upc: upc,
          url: url,
          image: color[:image],
          brand: brand,
          style_code: product_id,
        }
      end
    end

    prepare_items(results)
    process_results_batch(results)
  end

  def get_request(url, params={})
    super(URI(URI.encode(url)).to_s, params)
  end

  def process_in_batch(urls)
    batch.jobs do
      urls.each do |url|
        spawn_url('product', url)
      end
    end
  end
end
