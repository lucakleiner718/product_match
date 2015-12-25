class PopulateProductUpc

  def initialize(product_id)
    @product_id = product_id
  end

  def perform
    return false if product_upc_exists?

    product = Product.find(product_id)

    if product.upc.present?
      ProductSelect.where(product_id: product.id).delete_all
      return false
    end

    gtin = find_upc
    return false unless gtin

    product_select_ids = product_selects.pluck(:id)
    selected_ids = product_selects.pluck(:selected_id)

    ActiveRecord::Base.transaction do
      # update product with new upc
      product.update!(upc: gtin, match: false)

      # create new record about upc update
      ProductUpc.create!(product_id: product.id, selected_ids: selected_ids,
        product_select_ids: product_select_ids, upc: gtin)
    end

    # delete all suggestions for products as we found upc for it
    ProductSuggestion.where(product_id: product.id).delete_all
    # delete all suggestions with found upc
    ProductSuggestion.where(suggested_id: Product.where(upc: product.upc).pluck(:id)).delete_all

    true
  end

  private

  attr_accessor :product_id

  def product_upc_exists?
    ProductUpc.where(product_id: product_id).exists?
  end

  def product_selects_ids
    # select products selects uniq by user_id
    @selects_ids ||= ProductSelect.where(product_id: product_id, decision: :found).pluck(:id, :user_id).uniq{|el| el[1]}.map(&:first)
  end

  def product_selects
    ProductSelect.where(id: product_selects_ids)
  end

  def find_upc
    list = product_selects.joins(:selected).each_with_object(Hash.new(0)) do |el, obj|
      obj[el.selected.upc] += 1
    end
    list.select{|k, v| v >= 1}.to_a.sort_by(&:last).last.try(:first)
  end
end
