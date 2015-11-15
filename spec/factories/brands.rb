FactoryGirl.define do
  factory :brand, class: :Brand do
    name 'Some brand'
    in_use true
  end

  factory :brand_vince, class: :Brand do
    name 'Vince'
    in_use true
  end
end
