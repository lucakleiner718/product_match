module ApplicationHelper

  def paginate objects, options = {}
    options.reverse_merge!( theme: 'twitter-bootstrap-3' )

    super( objects, options )
  end

  def product_image image
    if image =~ /nordstrom/
      "http://sinatra-proxy-dl.herokuapp.com/?url=#{image}"
    else
      image
    end
  end

end
