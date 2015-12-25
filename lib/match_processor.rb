class MatchProcessor

  def initialize(current_user_id, product_id, decision, selected_id=nil)
    @current_user_id, @product_id, @decision, @selected_id =
      current_user_id, product_id, decision.to_s, selected_id
  end

  def process
    process_found
    process_nothing
    process_no_color
    process_no_size
    process_similar
  end

  private

  attr_reader :current_user_id, :product_id, :decision, :selected_id

  def product_suggestion
    @product_suggestion ||= ProductSuggestion.find_by(product_id: product_id, suggested_id: selected_id)
  end

  def product
    @product ||= Product.find(product_id)
  end

  def process_found
    if decision == 'found' && selected_id && product_suggestion
      product_select = ProductSelect.where(user_id: current_user_id, product_id: product_id,
        selected_id: selected_id, decision: decision).first_or_initialize
      product_select.selected_percentage = product_suggestion.percentage
      product_select.save!

      PopulateProductUpc.new(product_id).perform
    end
  end

  def process_nothing
    if decision == 'nothing'
      similar_products = Product.where(source: product.source, style_code: product.style_code).pluck(:id)
      similar_products.each do |pid|
        ProductSelect.create(user_id: current_user_id, product_id: pid, decision: decision)
      end
    end
  end

  def process_no_color
    if decision == 'no-color'
      similar_products = Product.where(source: product.source, style_code: product.style_code, color: product.color).pluck(:id)
      similar_products.each do |pid|
        ProductSelect.create!(user_id: current_user_id, product_id: pid, decision: decision)
      end
    end
  end

  def process_no_size
    if decision == 'no-size'
      ProductSelect.create(user_id: current_user_id, product_id: product_id, decision: decision)
    end
  end

  def process_similar
    if decision == 'similar' && selected_id && product_suggestion
      ProductSelect.create(user_id: current_user_id, product_id: product_id, selected_id: selected_id,
        selected_percentage: product_suggestion.percentage, decision: decision)
    end
  end
end