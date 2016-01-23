class DeleteProductImageWorker
  include Sidekiq::Worker

  def perform(image_url)
    connection = Fog::Storage.new(
      provider: 'AWS',
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )

    directory = connection.directories.get('upc-images')
    file = directory.files.create(key: filename, public: true)
    file.body = image_contents
    file.save
  end
end
