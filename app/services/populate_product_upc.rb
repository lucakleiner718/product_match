class PopulateProductUpc

  def self.perform product_select_id
    instance = self.new
    instance.perform product_select_id
  end

  def perform product_select_id
    return false if ProductUpc.where(product_select_id: product_select_id).size > 0

    product_select = ProductSelect.find(product_select_id)

    return false unless available_for_populate?(product_select)

    product = product_select.product
    selected = product_select.selected

    gtin = nil
    gtin = selected.upc if !gtin && selected.upc.present?
    gtin = selected.ean if !gtin && selected.ean.present?
    return false unless gtin

    ActiveRecord::Base.transaction do
      # update product with new upc
      product.update_column :upc, gtin

      # create new record about upc update
      ProductUpc.create product_id: product.id, selected_id: selected.id, product_select_id: product_select.id, upc: gtin
    end

    # delete all suggestions for products as we found upc for it
    ProductSuggestion.where(product_id: product.id).delete_all

    true
  end

  def available_for_populate? product_select
    product_decisions = ProductSelect.where(product_id: product_select.product_id).pluck(:decision)
    results = product_decisions.inject({}){|obj, dec| obj[dec] ||= 0; obj[dec] += 1; obj}
    product_can_be_populated? results
  end

  def self.for_populate
    self.new.for_populate
  end

  def for_populate
    products = {}
    ProductSelect.joins('LEFT JOIN product_upcs ON product_upcs.product_select_id=product_selects.id').where('product_upcs.id is null').pluck(:id, :decision).each do |id, decision|
      products[id] ||= {}
      products[id][decision] ||= 0
      products[id][decision] += 1
    end

    ids_to_populate = []
    products.each do |id, results|
      ids_to_populate << id if product_can_be_populated? results
    end

    ids_to_populate
  end

  def product_can_be_populated? results
    results.size == 1 && results['found']
  end

end