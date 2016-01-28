keys = ENV['AMAZON_IMPORT_KEY'].split(',')
secrets = ENV['AMAZON_IMPORT_SECRET'].split(',')
tags = ENV['AMAZON_IMPORT_TAG'].split(',')
index = rand(keys.size)

Amazon::Ecs.configure do |options|
  options[:AWS_access_key_id] = keys[index]
  options[:AWS_secret_key] = secrets[index]
  options[:associate_tag] = tags[index]
end