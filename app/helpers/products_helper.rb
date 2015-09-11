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

end
