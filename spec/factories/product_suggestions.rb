FactoryGirl.define do
  factory :product_suggestion, class: :ProductSuggestion do
    association :product, factory: :shopbop_product
    association :suggested, factory: :product_vince
  end
end
