FactoryGirl.define do
  factory :user, class: :User do
    email 'test@mail.com'
    password '123123123'
    initialize_with { User.find_or_create_by(email: email)}
  end
end
