Amazon::Ecs.configure do |options|
  options[:AWS_access_key_id] = ENV['AMAZON_IMPORT_KEY']
  options[:AWS_secret_key] = ENV['AMAZON_IMPORT_SECRET']
  options[:associate_tag] = ENV['AMAZON_IMPORT_TAG']
end