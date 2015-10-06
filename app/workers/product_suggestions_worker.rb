class ProductSuggestionsWorker

  include Sidekiq::Worker
  sidekiq_options queue: :default, unqiue: true

  def perform product_id
    product = Product.find(product_id)
    brand = Brand.get_by_name(product.brand) || Brand.create(name: product.brand)
    related_products = Product.where.not_shopbop.where(brand: brand.names).with_upc

    title_parts = product.title.split(/\s/).map(&:downcase) - ['the']
    special_category = Product::CLOTH_KIND & title_parts
    if special_category.size > 0
      special_category.each do |category|
        related_products = related_products.where("title ILIKE :word or category ILIKE :word", word: "%#{category}%")
      end
    else
      related_products = related_products.where(title_parts.map{|el| "title ILIKE #{Product.sanitize "%#{el}%"}"}.join(' OR '))
    end

    exists = ProductSuggestion.where(product_id: product.id, suggested_id: related_products.map(&:id)).inject({}){|obj, el| obj["#{el.product_id}_#{el.suggested_id}"] = el; obj}
    related_products.find_each do |suggested|
      percentage = product.similarity_to suggested
      ps = exists["#{product.id}_#{suggested.id}"]
      ps = ProductSuggestion.new product: product, suggested: suggested unless ps
      if percentage && percentage > 0
        ps.percentage = percentage
        begin
          ps.save if ps.changed?
        rescue ActiveRecord::RecordNotUnique => e
        end
      end
    end

    # delete not needed suggestions if we have some popular
    if ProductSuggestion.where(product_id: product.id).where('percentage > 50').size > 0
      ProductSuggestion.where(product_id: product.id).where('percentage <= 40').delete_all
    end
  end

end