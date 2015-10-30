class ProductsController < ApplicationController

  before_filter :authorize, except: [:match, :match_select]

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
    @sources = [['All', ''], ['Shopbop', 'shopbop'], ['Popshops', 'popshops'], ['Linksynergy', 'linksynergy']] +
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
          pr.title, pr.brand.try(:name), pr.source, pr.size, pr.color, pr.price, pr.price_sale, pr.style_code, (pr.upc || pr.ean), pr.retailer, pr.category
        ]
      end
    end

    filename = "upc-products#{"-#{brand.try(:name)}" if brand}-#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: filename
  end

  def match
    @brands_choose = Brand.in_use.order(:name)
    product_id = params[:product_id]

    unless product_id
      @brand = params[:brand_id] ? Brand.find(params[:brand_id]) : Brand.in_use.first

      products_ids = Product.shopbop.where(match: true).without_upc.joins(:suggestions)
      products_ids = products_ids.where(brand_id: @brand.id)
      if params[:only] == 'not_matched'
        products_ids = products_ids.joins("
          LEFT JOIN product_selects AS product_selects ON product_selects.product_id=products.id
        ").where("product_selects.id is null")
      else
        products_ids = products_ids.joins("
          LEFT JOIN product_selects AS product_selects ON product_selects.product_id=products.id
          AND
            (product_selects.decision='found' OR
              (product_selects.decision IN ('nothing', 'no-size', 'no-color', 'similar')
                AND product_selects.created_at > '#{1.day.ago}'
              )
            AND product_selects.user_id=#{current_user.id})"
        ).where("product_selects.id is null")
      end

      if params[:has_color] == 'green'
        products_ids = products_ids.where('product_suggestions.percentage = ?', 100)
      else
        products_ids = products_ids.where('product_suggestions.percentage > ?', 50)
      end

      products_ids = products_ids.order('title, color')
      product_id = products_ids.first.try(:id)
    end

    if product_id
      @product = Product.find(product_id)

      suggested_products = ProductSuggestion.where(product_id: product_id).joins(:suggested).where("products.upc is not null AND products.upc != ''").order('percentage desc').where('percentage is not null AND percentage > 0').limit(30).includes(:suggested)
      #show same upc close to green suggestion
      @suggested_products = []
      suggested_products.each do |product|
        @suggested_products << product unless @suggested_products.include?(product)
        if product.percentage == 100
          suggested_products.select{|pr| pr.suggested.upc == product.suggested.upc}.each do |pr|
            @suggested_products << pr unless @suggested_products.include?(pr)
          end
        end
      end

      @brand = @product.brand unless @brand
    end
  end

  def match_select
    if params[:decision] == 'found' && params[:selected_id]
      product_suggestion = ProductSuggestion.where(product_id: params[:product_id], suggested_id: params[:selected_id]).first
      if product_suggestion
        ProductSelect.create(user_id: current_user.id, product_id: params[:product_id], selected_id: params[:selected_id], selected_percentage: product_suggestion.percentage, decision: params[:decision])
        PopulateProductUpc.perform params[:product_id]
      end
    elsif params[:decision] == 'nothing'
      product = Product.find(params[:product_id])
      same_products_options = Product.where(source: product.source, style_code: product.style_code).pluck(:id)
      same_products_options.each do |product_id|
        ProductSelect.create(user_id: current_user.id, product_id: product_id, decision: params[:decision])
      end
    elsif params[:decision] == 'no-color'
      product = Product.find(params[:product_id])
      same_products_options = Product.where(source: product.source, style_code: product.style_code, color: product.color).pluck(:id)
      same_products_options.each do |product_id|
        ProductSelect.create(user_id: current_user.id, product_id: product_id, decision: params[:decision])
      end
    elsif params[:decision] == 'no-size'
      ProductSelect.create(user_id: current_user.id, product_id: params[:product_id], decision: params[:decision])
    elsif params[:decision] == 'similar' && params[:selected_id]
      product_suggestion = ProductSuggestion.where(product_id: params[:product_id], suggested_id: params[:selected_id]).first
      if product_suggestion
        ProductSelect.create(user_id: current_user.id, product_id: params[:product_id], selected_id: params[:selected_id], selected_percentage: product_suggestion.percentage, decision: params[:decision])
      end
    end

    render json: {}
  end

  def match_undo
    last_match = ProductSelect.joins(:product).where(user: current_user.id, products: { brand_id: params[:brand_id]}).where('product_selects.created_at > ?', 1.hour.ago).order(created_at: :desc).first
    if last_match
      if last_match.decision == 'found'
        ProductUpc.where(product_id: last_match.product_id).destroy_all
        Product.find(last_match.product_id).update_attributes upc: nil, match: true
        ProductSuggestionsWorker.new.perform last_match.product_id
        last_match.destroy
      elsif last_match.decision == 'nothing'
        product = last_match.product
        same_products_options = Product.where(source: product.source, style_code: product.style_code).pluck(:id)
        same_products_options.each do |product_id|
          ProductSelect.where(user_id: current_user.id, product_id: product_id, decision: :nothing).where('created_at > ?', 1.hour.ago).destroy_all
        end
      elsif last_match.decision == 'no-color'
        product = last_match.product
        same_products_options = Product.where(source: product.source, style_code: product.style_code, color: product.color).pluck(:id)
        same_products_options.each do |product_id|
          ProductSelect.where(user_id: current_user.id, product_id: product_id, decision: 'no-color').where('created_at > ?', 1.hour.ago).destroy_all
        end
      elsif last_match.decision == 'no-size' || last_match.decision == 'similar'
        last_match.destroy
      end
    end
    render json: {}
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
        'New today', 'New this week', 'Match Page'
      ]
      brands.each do |brand|
        stat = brand.stat
        csv << [
          brand.name, stat.shopbop_size, stat.shopbop_noupc_size, stat.shopbop_matched_size, stat.shopbop_nothing_size,
          stat.amounts_values, stat.suggestions, stat.suggestions_green, stat.suggestions_yellow,
          stat.new_match_today, stat.new_match_week, "http://upc.socialrootdata.com/match?brand_id=#{brand.id}"
        ]
      end
    end

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "upc-brands-statistic-#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
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

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "shopbop-upc-#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"
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

  helper_method :sort_column, :sort_direction

  private

  def sort_column
    params[:sort] || 'name'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : (sort_column == 'name' ? "asc" : 'desc')
  end

  def authorize
    redirect_to(match_path) unless current_user.is_admin?
  end

end
