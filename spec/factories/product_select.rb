FactoryGirl.define do
  factory :product_select, class: :ProductSelect do
    association :product, factory: :shopbop_product
    association :selected, factory: :product_vince
    association :user
  end
end
