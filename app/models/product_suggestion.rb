class ProductSuggestion < ActiveRecord::Base

  belongs_to :product
  belongs_to :suggested, class_name: 'Product', foreign_key: :suggested_id

  def self.fill brand: nil
    ProductSuggestionsWorker.spawn brand: brand
  end

end
