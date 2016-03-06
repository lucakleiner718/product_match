class MatchController < ApplicationController

  def show
    @brands_choose = Brand.in_use.order(:name)
    if !params[:brand_id] && !params[:product_id]
      redirect_to match_path(brand_id: @brands_choose.first.id)
      return
    end

    product_id = params[:product_id]
    unless product_id
      @brand = Brand.find(params[:brand_id])

      products_ids = Product.matching.where(match: true).without_upc.joins(:suggestions)
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
            AND product_selects.user_id=#{current_user.id})
        ").where("product_selects.id is null")
        # .joins("
        #   JOIN (
        #     SELECT MAX(id) as id, product_id, created_at
        #     FROM product_selects
        #     GROUP BY product_id, created_at
        #   ) as product_selects2 ON product_selects2.product_id=products.id AND (product_selects2.id is null OR product_selects2.created_at < product_suggestions.updated_at)
        # ")
      end

      if params[:only] == 'new_match_week'
        products_ids = products_ids.where('products.created_at >= ?', Time.now.in_time_zone.monday)
      elsif params[:only] == 'new_match_today'
        products_ids = products_ids.where('products.created_at >= ?', 1.day.ago)
      end

      if params[:has_color] == 'green' || params[:only] == 'has_green'
        products_ids = products_ids.where('product_suggestions.percentage >= 90', 100)
      end

      @products_left = products_ids.uniq.size

      products_ids = products_ids.order('source_id, title, color')
      product_id = products_ids.first.try(:id)
    end

    if product_id
      @product = Product.find(product_id)

      @upc_patterns = @product.upc_patterns

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

      @last_product_select = ProductSelect.order(created_at: :desc).where(product_id: @product.id).first
    end

    if !@product && @brand
      BrandStatWorker.perform_async(@brand.id)
    end

    @last_match = ProductSelect.joins(:product).where(user: current_user.id, products: { brand_id: params[:brand_id]})
                   .where('product_selects.created_at > ?', 1.hour.ago).exists?

    if @product && @product.upc.present? && product_upc = ProductUpc.find_by!(product_id: @product.id)
      @selected_products = product_upc.selected
    end
  end

  def select
    MatchProcessor.new(current_user.id, params[:product_id], params[:decision],
      params[:selected_id]).process
    render json: {}
  end

  def undo
    last_match = ProductSelect.joins(:product).where(user: current_user.id, products: { brand_id: params[:brand_id]})
                   .where('product_selects.created_at > ?', 1.hour.ago).order(created_at: :desc).first
    if last_match
      if last_match.decision == 'found'
        ProductUpc.where(product_id: last_match.product_id).destroy_all
        Product.find(last_match.product_id).update! upc: nil, match: true
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

end
