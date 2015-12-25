FactoryGirl.define do
  factory :brand, class: :Brand do
    name 'Some brand'
    in_use true
    initialize_with { Brand.find_or_create_by(name: name)}
  end

  factory :brand_vince, parent: :brand do
    name 'Vince'
  end
end
