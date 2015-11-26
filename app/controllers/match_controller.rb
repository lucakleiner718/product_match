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
            AND product_selects.user_id=#{current_user.id})"
        ).where("product_selects.id is null")
      end

      if params[:only] == 'new_match_week'
        products_ids = products_ids.where('products.created_at >= ?', Time.in_time_zone.now.monday)
      elsif params[:only] == 'new_match_today'
        products_ids = products_ids.where('products.created_at >= ?', 1.day.ago)
      end

      if params[:has_color] == 'green' || params[:only] == 'has_green'
        products_ids = products_ids.where('product_suggestions.percentage = ?', 100)
      else
        products_ids = products_ids.where('product_suggestions.percentage > ?', 50)
      end

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
    end
  end

  def select
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

  def undo
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

end
