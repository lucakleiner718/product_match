class ProductsController < ApplicationController

  def root
    redirect_to products_path
  end

  def index
    @products = Product.all

    if params[:brand]
      @products = @products.where(brand: params[:brand])
    end

    if params[:title]
      @products = @products.where('title ILIKE ?', "%#{params[:title]}%")
    end

    if params[:source]
      @products = @products.where(source: params[:source])
    end

    if params[:upc]
      @products = @products.where(upc: params[:upc])
    end

    if params[:retailer]
      @products = @products.where(retailer: params[:retailer])
    end

    # @products = @products.where("(source = 'shopbop' AND (upc is null OR upc = '')) OR (source != 'shopbop' AND upc is not null AND upc != '')")

    @products = @products.order(title: :asc).page(params[:page]).per(50)
  end

  def match
    # product_id = params[:product_id]
    # product_id ||= Product.where(source: :shopbop).where('upc is NULL').where(brand: 'Current/Elliott').limit(100_000).pluck(:id).sample
    # @product = Product.find(product_id)
    #
    # @related_products = Product.where.not(source: :shopbop).where(brand: @product.brand)
    #
    # title_parts = @product.title.split(/\s/).map(&:downcase) - ['the']
    # special_category = ['shorts', 'skirt', 'dress'] & title_parts
    # if special_category.size > 0
    #   special_category.each do |category|
    #     @related_products = @related_products.where("title ILIKE :word or category ILIKE :word", word: "%#{category}%")
    #   end
    # else
    #   @related_products = @related_products.where(title_parts.map{|el| "title iLIKE '%#{el}%'"}.join(' OR '))
    # end
    #
    # @related_products = @related_products.where('lower(color) = lower(?)', @product.color) if @product.color.present?
    # # @related_products = @related_products.where('lower(size) = lower(?)', @product.size) if @product.size.present?
    #
    # @related_products = @related_products.limit(1000).sample(100)

    @brands_choose = Brand.order(:name).in_use

    product_id = params[:product_id]
    unless product_id
      products_ids = ProductSuggestion.where('percentage > 50').select('distinct(product_id)', 'products.title').joins(:product).order('products.title')
      if params[:brand]
        brand = Brand.where(name: params[:brand]).first
        products_ids = products_ids.where(products: { brand: brand.names }) if brand
      else
        products_ids = products_ids.where(products: { brand: Brand.names_in_use })
      end

      selected_products = ProductSelect.where(user_id: current_user.id).pluck(:product_id).uniq
      products_ids = products_ids.where.not(product_id: selected_products) if selected_products.size > 0

      product_id = products_ids.first.try(:product_id)
    end
    if product_id
      @product = Product.find(product_id)
      @suggested_products = ProductSuggestion.where(product_id: product_id).order(percentage: :desc).where('percentage is not null AND percentage > 0').limit(20).joins(:suggested).where("products.upc is not null AND products.upc != ''")
    end
  end

  def match_select
    if params[:decision] == 'found' && params[:selected_id]
      product_suggestion = ProductSuggestion.where(product_id: params[:product_id], suggested_id: params[:selected_id]).first
      if product_suggestion
        ProductSelect.create(user_id: current_user.id, product_id: params[:product_id], selected_id: params[:selected_id], selected_percentage: product_suggestion.percentage, decision: params[:decision])
      end
    elsif params[:decision].in?(['nothing', 'no-size', 'no-color'])
      ProductSelect.create(user_id: current_user.id, product_id: params[:product_id], decision: params[:decision])
    end

    render json: { }
  end

  def statistic
    @brands = Brand.in_use.order(:name)
  end

  def statistic_brand
    brand = Brand.find(params[:brand_id])

    resp =
      Rails.cache.fetch "brand/#{brand.id}/data", expires_in: 1.day do
        amounts = Product.amount_by_brand_and_source(brand.names)
        {
          name: brand.name,
          shopbop_size: Product.where(brand: brand.names).shopbop.size,
          shopbop_noupc_size: Product.where(brand: brand.names).shopbop.where("upc is null OR upc = ''").size,
          amounts_content: amounts.to_a.map{|el| el.join(': ')}.join('<br>'),
          amounts_values: amounts.values.sum,
          suggestions: ProductSuggestion.select('distinct(product_id').joins(:product).where(products: { brand: brand.names}).pluck(:product_id).uniq.size
        }
      end

    respond_to do |format|
      format.json { render json: resp }
    end
  end

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

end
