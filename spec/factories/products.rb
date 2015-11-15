FactoryGirl.define do
  factory :shopbop_product, class: :Product do
    association :brand, name: 'Vince'
    brand_name 'Vince'
    source 'shopbop'
    source_id 'VINCE2060510495112'
    kind nil
    retailer nil
    title 'Favorite Tank'
    category 'Clothing > Tops > Tank Tops'
    url 'https://www.shopbop.com/favorite-tank-vince/vp/v=1/845524441852318.htm?currencyCode=USD&extid=SE_AMZN_PAds&cvosrc=cse.amazon.sbusd'
    image 'https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q1_1-3._QL90_UX336_.jpg'
    additional_images ["https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q1_1-3._QL90_UX336_.jpg",
        "https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q2_1-2._QL90_UX336_.jpg",
        "https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q3_1-2._QL90_UX336_.jpg",
        "https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q5_1-2._QL90_UX336_.jpg",
        "https://images-na.ssl-images-amazon.com/images/G/01/Shopbop/p/pcs/products/vince/vince2060510495/vince2060510495_q4_1-1._QL90_UX336_.jpg"]
    price "48.0"
    price_sale nil
    color 'Heather Grey'
    size 'XS'
    material 'Pima Cotton, Viscose'
    gender 'Female'
    upc nil
    mpn nil
    ean nil
    sku nil
    style_code 'VINCE20605'
    item_group_id nil
    google_category 'Apparel & Accessories > Clothing > Shirts & Tops'
    description nil
    match true
    image_local nil
    additional_images_local []
  end

  factory :shopbop_product_suggestion, class: :Product do
    association :brand, name: 'Vince'
    brand_name 'Vince'
    source 'test'
    title 'Favorite Tank'
    price "48.0"
    color 'Heather Grey'
    size 'XS'
    gender 'Female'
    upc '822508892303'
    match false
  end

  factory :shopbop_product_suggestion_rand, class: :Product do
    association :brand, name: 'Vince'
    brand_name 'Vince'
    source 'test'
    title 'Favorite Tank'
    price "48.0"
    color 'Heather Grey'
    size 'XS'
    gender 'Female'
    upc '822508892303'
    match false
  end
end
