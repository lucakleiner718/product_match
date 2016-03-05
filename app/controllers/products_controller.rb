class ProductsController < ApplicationController

  before_filter :authorize

  def root
    redirect_to statistic_products_path
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
      @products = @products.where(retailer: f[:retailer]) if f[:retailer].present?
      @products = @products.without_upc if f[:no_upc]
      @products = @products.where(style_code: f[:style_code]) if f[:style_code].present?
    end

    @products = @products.order(:title).page(params[:page]).per(50)

    @filter_brands = Brand.in_use.order(:name)
    @sources = {'All' => ''}.merge(ProductSource::SOURCES).merge(
      ProductSource.where(source_name: :website).pluck(:source_id)
        .map{|cn| Module.const_get("Import::#{cn}").new.baseurl}.compact
        .map{|url| URI(url).host.sub(/^www\./, '')}
        .each_with_object({}){|host, obj| obj[host] = host})
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
      @products = @products.where(retailer: f[:retailer]) if f[:retailer].present?
      @products = @products.without_upc if f[:no_upc]
      @products = @products.where(style_code: f[:style_code]) if f[:style_code].present?
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

  def show
    @product = Product.find(params[:id])
  end


  def active
    @active_products = ActiveProduct.includes(:brand)
                         .order("#{params[:sort] || 'title'} #{params[:direction] || 'asc'}")

    if params[:filter]
      f = params[:filter]
      @search = true

      @active_products = @active_products.where(brand: f[:brand]) if f[:brand].present?
      @active_products = @active_products.where(brand_id: f[:brand_id]) if f[:brand_id].present?
      if f[:retailers_count].present?
        @active_products = @active_products.where(retailers_count: f[:retailers_count])
      else
        @active_products = @active_products.where('retailers_count > 0')
      end
      @active_products = @active_products.where('shopbop_added_at >= ?', Date.strptime(f[:shopbop_added_at_from], "%m/%d/%Y")) if f[:shopbop_added_at_from].present?
      @active_products = @active_products.where('shopbop_added_at <= ?', Date.strptime(f[:shopbop_added_at_to], "%m/%d/%Y")) if f[:shopbop_added_at_to].present?
    end

    @filter_brands = Brand.in_use.order(:name)
    @active_products = @active_products.page(params[:page]).per(50)
  end

  def active_show
    @active_product = ActiveProduct.find(params[:id])
    @active_products_upc = Product.where(source: @active_product.source).where(style_code: @active_product.style_code).pluck(:upc).compact
    if @active_products_upc.any?
      @other_retailers = Product.not_matching.where(upc: @active_products_upc).select('distinct(style_code), *').group_by{|el| el.source}
    end
  end

  def active_export
    brand = nil
    @active_products = ActiveProduct.includes(:brand)
                         .order("#{params[:sort] || 'title'} #{params[:direction] || 'asc'}")

    if params[:filter]
      f = params[:filter]
      @search = true

      brand = f[:brand] if f[:brand]

      @active_products = @active_products.where(brand: f[:brand]) if f[:brand].present?
      @active_products = @active_products.where(brand_id: f[:brand_id]) if f[:brand_id].present?
      if f[:retailers_count].present?
        @active_products = @active_products.where(retailers_count: f[:retailers_count])
      else
        @active_products = @active_products.where('retailers_count > 0')
      end
      @active_products = @active_products.where('shopbop_added_at >= ?', Date.strptime(f[:shopbop_added_at_from], "%m/%d/%Y")) if f[:shopbop_added_at_from].present?
      @active_products = @active_products.where('shopbop_added_at <= ?', Date.strptime(f[:shopbop_added_at_to], "%m/%d/%Y")) if f[:shopbop_added_at_to].present?
    else
      @active_products = @active_products.where('retailers_count > 0')
    end

    csv_string = CSV.generate do |csv|
      csv << [
        'Brand', 'Title', 'Price', 'Category', 'Date added to Shopbop',
        'Retailer product count', 'Link to Shopbop product'
      ]
      @active_products.each do |ap|
        csv << [
          ap.brand.try(:name), ap.title, ap.price, ap.category,
          ap.shopbop_added_at.to_s(:long), ap.retailers_count,
          active_show_products_url(ap)
        ]
      end
    end

    filename = "upc-active-products#{"-#{brand.name}" if brand}-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
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

    unless params[:sort]
      params[:sort] = 'stats.not_matched'
      params[:direction] = :desc
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
        unless stat
          BrandStatWorker.new.perform(brand.id)
          stat = brand.reload.stat
        end

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

  helper_method :sort_column, :sort_direction

  private

  def sort_column
    params[:sort] || 'name'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : (sort_column == 'name' ? "asc" : 'desc')
  end

  def authorize
    if current_user.admin?
      true
    elsif current_user.manager? && ['statistic', 'marketing', 'statistic_export'].exclude?(params[:action])
      redirect_to(statistic_products_path, alert: "You don't have access to this page")
    elsif current_user.regular? && ['match', 'match_select'].exclude?(params[:action])
      redirect_to(match_path, alert: "You don't have access to this page")
    end
  end

end
