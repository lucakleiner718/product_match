module ProductsHelper

  def match_item_bg suggest_item
    if suggest_item.percentage == 100
      "rgba(0,255,0,0.5)"
    elsif suggest_item.percentage > 50
      "rgba(255,255,0,#{suggest_item.percentage.to_f/100})"
    else
      "rgba(255,0,0,0.5)"
    end
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = column == sort_column ? "current #{sort_direction}" : nil
    direction = column == sort_column && sort_direction == "asc" ? "desc" : "asc"
    direction = 'desc' if column != sort_column && column != 'name'
    link_to title, {:sort => column, :direction => direction}, {:class => css_class}
  end

  def suggestion_image url
    content_tag :div, class: 'img-wrap zoom-image' do
      image_tag(product_image(url), class: 'img-responsive')
    end
  end

end
