class PopulateProductUpc

  def self.perform product_id
    instance = self.new
    instance.perform product_id
  end

  def perform product_id
    return false if ProductUpc.where(product_id: product_id).size > 0 || !available_for_populate?(product_id)

    product = Product.find(product_id)

    if product.upc.present?
      ProductSelect.where(product_id: product.id).delete_all
      return false
    end

    product_select = ProductSelect.where(product_id: product.id, decision: :found).first
    selected = product_select.selected

    gtin = nil
    gtin = selected.upc if selected.upc.present?
    unless gtin
      product_select.delete
      return false
    end

    ActiveRecord::Base.transaction do
      # update product with new upc
      product.update! upc: gtin, match: false

      # create new record about upc update
      ProductUpc.create product_id: product.id, selected_id: selected.id, product_select_id: product_select.id, upc: gtin
    end

    # delete all suggestions for products as we found upc for it
    ProductSuggestion.where(product_id: product.id).delete_all
    # delete all suggestions with found upc
    ProductSuggestion.where(suggested_id: Product.where(upc: product.upc).pluck(:id)).delete_all

    true
  end

  def available_for_populate? product_id
    product_decisions = ProductSelect.where(product_id: product_id).pluck(:decision)
    results = product_decisions.inject({}){|obj, dec| obj[dec] ||= 0; obj[dec] += 1; obj}
    product_can_be_populated? results
  end

  def self.for_populate
    self.new.for_populate
  end

  # Return ids, which can be populated with upc, using selects from match page (found)
  # @return [array] of Product ids
  def for_populate
    decision = 'found'
    products = {}
    products_ids = ProductSelect.connection.execute("
      SELECT product_selects.product_id
      FROM (
        SELECT distinct(product_id)
        FROM product_selects
        WHERE decision='#{decision}'
      ) as product_selects
      LEFT JOIN product_upcs ON product_upcs.product_id=product_selects.product_id
      WHERE product_selects.product_id is not null and product_upcs.id is null
    ").to_a.map{|r| r['product_id']}
    products_ids.each do |product_id|
      products[product_id] ||= {}
      products[product_id][decision] ||= 0
      products[product_id][decision] += 1
    end

    ids_to_populate = []
    products.each do |id, results|
      ids_to_populate << id if product_can_be_populated? results
    end

    ids_to_populate
  end

  def product_can_be_populated? results
    results['found'] && results['found'] > 0
  end

end