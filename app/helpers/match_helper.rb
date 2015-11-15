module MatchHelper

  def match_item_bg suggest_item
    if suggest_item.percentage == 100
      "rgba(0, 165, 0, 1)"
    elsif suggest_item.percentage < 100 && suggest_item.percentage >= 90
      "rgba(190, 255, 0, 0.5)"
    elsif suggest_item.percentage < 90 && suggest_item.percentage >= 60
      "rgba(255, 255, 0, 0.5)"
    elsif suggest_item.percentage < 60 && suggest_item.percentage >= 50
      "rgba(90, 90, 96, 0.3)"
    elsif suggest_item.percentage < 50
      "rgba(90, 90, 96, 0.1)"
    end
  end

  def product_upc upc, upc_patterns, product_upc_patterns
    pattern = upc_patterns.find{|pat| upc =~ /^#{pat}/}
    pattern = product_upc_patterns.find{|pat| upc =~ /^#{pat}/} unless pattern
    if pattern
      upc.sub(/^#{pattern}/, "<span class='upc-pattern'>#{pattern}</span>").html_safe
    else
      upc
    end
  end

end
