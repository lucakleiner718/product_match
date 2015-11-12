require 'open-uri'

class ImageLocalWorker
  include Sidekiq::Worker

  def perform product_id
    product = Product.find(product_id)

    if product.image_local.blank?
      image = upload_image(product, product.image)
      product.image_local = image if image
    end

    if product.additional_images_local.size == 0 && product.additional_images.size > 0
      additional_images = product.additional_images.map do |image_url|
        upload_image(product, image_url)
      end.compact
      product.additional_images_local = additional_images if additional_images.size > 0
    end

    product.save! if product.changed?
  end

  def upload_image product, image_url
    if Rails.env.development? && image_url =~ /nordstrom/
      image_url = "http://sinatra-proxy-dl.herokuapp.com/?url=#{image_url}"
    end

    "http:#{image_url}" if image_url[0,2] == '//'

    extension = image_url.match(/\.(jpg|png|jpeg|gif)\??/) && $1 || 'jpg'
    filename = "#{product.id}-#{DateTime.now.strftime("%Y%d%m-%s")}-#{Digest::SHA1.hexdigest image_url}-#{SecureRandom.hex(4)}.#{extension}"
    image_contents = open(image_url).read rescue nil

    return false if image_contents.blank?

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