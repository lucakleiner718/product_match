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

    product_id = params[:product_id]
    unless product_id
      products_ids = ProductSuggestion.where('percentage > 50').select('distinct(product_id)').joins(:product).where(products: { brand: ['Current/Elliott', 'Eberjey', 'Joie', 'Honeydew Intimates'] }).to_a.map(&:product_id)
      product_id = products_ids.sample
    end
    @product = Product.find(product_id)

    @suggested_products = ProductSuggestion.where(product_id: product_id).order(percentage: :desc).includes(:suggested)
  end

  def match_select
    product_suggestion = ProductSuggestion.where(product_id: params[:product_id], suggested_id: params[:selected_id]).first
    if product_suggestion
      ProductSelect.create(product_id: params[:product_id], selected_id: params[:selected_id], selected_percentage: product_suggestion.percentage)
    end

    render json: { }
  end

  def statistic

  end

end
