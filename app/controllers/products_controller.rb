class ProductsController < ApplicationController

  before_filter :authorize

  def root
    redirect_to products_path
  end

  def index
    @products = Product.all.includes(:brand)

    if params[:filter]
      f = params[:filter]
      @search = true

      @products = @products.where(brand: f[:brand]) if f[:brand]

      if f[:brand_id].present?
        brand = Brand.where(id: f[:brand_id]).first
        @products = @products.where(brand_id: brand.id) if brand
      end

      @products = @products.where('title ILIKE ?', "%#{f[:title]}%") if f[:title]
      @products = @products.where(source: f[:source]) if f[:source].present?
      @products = @products.where(upc: f[:upc]) if f[:upc]
      @products = @products.where(retailer: f[:retailer]) if f[:retailer]
      @products = @products.without_upc if f[:no_upc]
    end

    @products = @products.order(:title).page(params[:page]).per(50)

    @filter_brands = Brand.in_use.order(:name)
    @sources = [['All', ''], ['Shopbop', 'shopbop'], ['Eastdane', 'eastdane'], ['Popshops', 'popshops'], ['Linksynergy', 'linksynergy']] +
      ProductSource.where(source_name: :website).pluck(:source_id).map{|cn| URI(Module.const_get("Import::#{cn}").new.baseurl).host.sub(/^www\./, '')}.map{|host| [host, host]}
  end

  def index_export
    @products = Product.all.includes(:brand)
    brand = nil

    if params[:filter]
      f = params[:filter]
      @search = true

      @products = @products.where(brand: f[:brand]) if f[:brand]

      if f[:brand_id].present?
        brand = Brand.where(id: f[:brand_id]).first
        @products = @products.where(brand_id: brand.id) if brand
      end

      @products = @products.where('title ILIKE ?', "%#{f[:title]}%") if f[:title]
      @products = @products.where(source: f[:source]) if f[:source].present?
      @products = @products.where(upc: f[:upc]) if f[:upc]
      @products = @products.where(retailer: f[:retailer]) if f[:retailer]
      @products = @products.without_upc if f[:no_upc]
    end

    @products = @products.order(:title)

    csv_string = CSV.generate do |csv|
      csv << [
        'Title', 'Brand', 'Source', 'Size', 'Color', 'Price', 'Price Sale', 'Style Code', 'UPC', 'Retailer', 'Category'
      ]
      @products.each do |pr|
        csv << [
          pr.title, pr.brand.try(:name), pr.source, pr.size, pr.color, pr.price, pr.price_sale,
          pr.style_code, pr.upc, pr.retailer, pr.category
        ]
      end
    end

    filename = "upc-products#{"-#{brand.try(:name)}" if brand}-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: filename
  end

  def statistic
    brands = Brand.in_use.joins(:brand_stat).includes(:brand_stat)

    if params[:brand]
      brands = brands.where('name ILIKE ?', "%#{params[:brand]}%")
    end
    if params[:brand_id]
      brands = brands.where(id: params[:brand_id])
    end

    if params[:sort] =~ /^stats\./
      col = params[:sort].match(/^stats\.(.*)$/)[1]
      brands = brands.order("brand_stats.#{col} #{sort_direction}")
    else
      brands = brands.order("#{sort_column} #{sort_direction}")
    end
    @brands = brands.page(params[:page]).per(20)
  end

  def statistic_export
    brands = Brand.in_use.includes(:brand_stat).order(:name)

    csv_string = CSV.generate do |csv|
      csv << [
        'Brand Name', 'Shopbop Products', 'Shopbop Products without UPC', 'Shopbop Products Matched', 'Shopbop Products Nothing',
        'Other sources Products with UPC', 'Products with Suggestions', 'Green Suggestions Products', 'Yellow Suggestions Products',
        'New today', 'New this week', 'Not matched', 'Match Page'
      ]
      brands.each do |brand|
        stat = brand.stat
        csv << [
          brand.name, stat.shopbop_size, stat.shopbop_noupc_size, stat.shopbop_matched_size, stat.shopbop_nothing_size,
          stat.amounts_values, stat.suggestions, stat.suggestions_green, stat.suggestions_yellow,
          stat.new_match_today, stat.new_match_week, stat.not_matched,
          "http://upc.socialrootdata.com/match?brand_id=#{brand.id}"
        ]
      end
    end

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "upc-brands-statistic-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
  end

  # def statistic_brand
  #   brand_id = params[:brand_id]
  #   brand = Brand.find(brand_id)
  #
  #   respond_to do |format|
  #     format.json { render json: brand.stat }
  #   end
  # end

  def selected
    @products = selected_products
    @products = @products.values.sort{|a,b| b[:found_votes] <=> a[:found_votes]}
  end

  def selected_export
    products = selected_products.values

    if params[:only]
      if params[:only] == 'found'
        products.select!{|r| r[:found_votes] > 0}
      end
    end

    csv_string = CSV.generate do |csv|
      csv << [
        'item_group_id', 'id', 'title', 'found_match', 'no_match', 'no_color_match', 'no_size_match', 'avg_similarity',
        'product_type', 'google_product_category', 'link', 'brand', 'color', 'size', 'gtin'
      ]
      products.each do |row|
        pr = row[:product]
        csv << [
          pr.style_code, pr.source_id, pr.title, row[:found_votes], row[:nothing_votes], row[:no_color_votes],
          row[:no_size_votes], row[:avg_similarity], pr.category, pr.google_category, pr.url, pr.brand,
          pr.color, pr.size, (row[:selected].upc if row[:selected])
        ]
      end
    end

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "shopbop-upc-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
  end

  def selected_products
    # ProductSelect.includes(:product, :selected).all.each do |select|
    #   @products[select.product_id] ||= {
    #     product: select.product,
    #     selected: select.selected,
    #     found_votes: 0,
    #     nothing_votes: 0,
    #     no_color_votes: 0,
    #     no_size_votes: 0,
    #     total_similarity: 0,
    #     count: 0
    #   }
    #   if select[:decision] == 'found'
    #     @products[select.product_id][:found_votes] += 1
    #     @products[select.product_id][:total_similarity] += select.selected_percentage
    #     @products[select.product_id][:count] += 1
    #   elsif select[:decision] == 'no-color'
    #     @products[select.product_id][:no_color_votes] += 1
    #   elsif select[:decision] == 'no-size'
    #     @products[select.product_id][:no_size_votes] += 1
    #   elsif select[:decision] == 'nothing'
    #     @products[select.product_id][:nothing_votes] += 1
    #   end
    # end

    ar = ProductSelect.connection.execute("
SELECT *
FROM (
  SELECT product_id, selected_id,
    sum(CASE WHEN decision='found' THEN 1 ELSE 0 END) as found_count,
    sum(CASE WHEN decision='no-color' THEN 1 ELSE 0 END) as no_color_count,
    sum(CASE WHEN decision='no-size' THEN 1 ELSE 0 END) as no_size_count,
    sum(CASE WHEN decision='nothing' THEN 1 ELSE 0 END) as nothing_count,
    count(product_id) as amount,
    sum(selected_percentage) as similarity,
    (sum(selected_percentage)/count(product_id)) as avg_similarity
  FROM product_selects
  GROUP by product_id, selected_id
) AS t
ORDER BY t.found_count desc, avg_similarity desc
").to_a

    products_ids = ar.map{|row| row['product_id']} + ar.map{|row| row['selected_id']}
    products_exists = Product.where(id: products_ids)

    products = {}
    ar.each do |row|
      products[row['product_id']] = {
        product: products_exists.select{|pr| pr.id == row['product_id'].to_i}.first,
        selected: (products_exists.select{|pr| pr.id == row['selected_id'].to_i}.first if row['selected_id']),
        found_votes: row['found_count'].to_i,
        nothing_votes: row['nothing_count'].to_i,
        no_color_votes: row['no_color_count'].to_i,
        no_size_votes: row['no_size_count'].to_i,
        total_similarity: row['similarity'].to_i,
        count: row['amount'].to_i,
        avg_similarity: row['avg_similarity'].to_i
      }
    end

    products
  end

  def marketing
    chart = StatChart.new.data
    @chart_db = [
      {name: 'Total products', data: chart[:total_products]},
      {name: 'Total without UPC', data: chart[:total_without_upc]},
    ]
    @chart_shopbop_file = [
      {name: 'Total products published', data: chart[:total_products_published]},
      {name: 'Total without UPC published', data: chart[:total_without_upc_published]},
    ]
    @chart_matching = [
      {name: 'Added without UPC', data: chart[:added_without_upc]},
      {name: 'Managed', data: chart[:matched]},
    ]

    @links = Dir.glob('public/downloads/shopbop_products_upc-*').sort.reverse[0..9].sort.map do |l|
      [
        l.sub(/^public/, ''),
        l.match(/shopbop_products_upc-([\d_]{8})/)[1].gsub('_', '/'),
        File.readlines(l).size,
        File.mtime(l)
      ]
    end
    @links = [[
      '/downloads/shopbop_products_upc.csv',
      'Current week',
      File.readlines('public/downloads/shopbop_products_upc.csv').size,
      File.mtime('public/downloads/shopbop_products_upc.csv')
    ]] + @links
  end

  helper_method :sort_column, :sort_direction

  private

  def sort_column
    params[:sort] || 'name'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : (sort_column == 'name' ? "asc" : 'desc')
  end

  def authorize
    if current_user.manager? && !params[:action].in?(['statistic', 'marketing'])
      redirect_to(products_statistic_path) unless current_user.is_admin?
    elsif current_user.regular? && !params[:action].in?(['match', 'match_select'])
      redirect_to(match_path)
    end
  end

end
