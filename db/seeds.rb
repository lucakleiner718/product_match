# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

User.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password', role: 'admin') if User.count == 0

if Brand.count == 0
  ['Current/Elliott', 'Eberjey', 'Joie', 'Honeydew Intimates'].each do |brand_name|
    brand = Brand.where(name: brand_name).first_or_initialize
    brand.in_use = true
    brand.save!
  end
end

