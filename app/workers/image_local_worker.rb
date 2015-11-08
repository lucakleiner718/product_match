require 'open-uri'

class ImageLocalWorker
  include Sidekiq::Worker

  # def initialize
  #   super
  #   @s3 = Aws::S3::Client.new
  # end

  def perform product_id
    product = Product.find(product_id)
    main_image = product.image
    binding.pry

    local_main_image = upload_image(product, main_image)



    # image_hash = Digest::SHA1.hexdigest(main_image) + main_image.match(/(\.\w+)$/)[1]
    # @s3.put_object({
    #   bucket: 'upc-images',
    #   key: image_hash,
    #   body: open(main_image).read,
    #   acl: 'public-read'
    # })
    # obj.public_url
  end

  def upload_image product, image_url
    extension = image_url.match(/\.(\w+)\z/)[1]
    filename = "#{product.id}-#{DateTime.now.strftime("%Y%d%m-%s")}-#{SecureRandom.hex(4)}.#{extension}"
    image_contents = open(image_url).read

    connection = Fog::Storage.new(
      provider: 'AWS',
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    )

    directory = connection.directories.get('upc-images')
    file = directory.files.create(key: filename, public: true)
    file.body = image_contents
    file.save

    file.public_url
  end
end