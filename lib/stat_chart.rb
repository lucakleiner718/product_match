class StatChart
  def initialize
    @results = {
      total_products: [],
      total_products_published: [],
      total_without_upc: [],
      total_without_upc_published: [],
      added_without_upc: [],
      matched: []
    }
  end

  def build_data
    grab_main_stat
    grab_amounts_without_upc
    grab_matched

    @results
  end

  private

  def grab_main_stat
    stats = StatAmount.where('date > ?', 6.months.ago)
              .where(key: ['shopbop_total', 'not_matched_size', 'shopbop_total_published', 'not_matched_size_published'])
              .order(:date)
    stats.each do |s|
      item = [s.date.to_time.to_i*1000, s.value]
      if s.key == 'shopbop_total'
        @results[:total_products] << item
      elsif s.key == 'shopbop_total_published'
        @results[:total_products_published] << item
      elsif s.key == 'not_matched_size'
        @results[:total_without_upc] << item
      elsif s.key == 'not_matched_size_published'
        @results[:total_without_upc_published] << item
      end
    end
  end

  def grab_amounts_without_upc
    dates = Product.matching.without_upc.where('created_at > ?', 2.months.ago.beginning_of_day).order(:created_at).pluck(:created_at)
    @results[:added_without_upc] =
      dates_to_weeks(dates).map do |el|
        week = el['created_week'].split('-').map(&:to_i)
        [Date.commercial(week.first, week.last+1, 7).to_time.to_i*1000, el['count'].to_i]
      end
  end

  def grab_matched
    matched = ProductUpc.where('created_at > ?', 2.months.ago.beginning_of_day).order(:created_at).pluck(:created_at)
    @results[:matched] =
      dates_to_weeks(matched).map do |el|
        week = el['created_week'].split('-').map(&:to_i)
        [Date.commercial(week.first, week.last+1, 7).to_time.to_i*1000, el['count'].to_i]
      end
  end

  def dates_to_weeks(dates)
    dates.map{|date| date.strftime("%Y-%U")}.group_by{|e| e}
         .each_with_object([]){|(k,v), ar| ar << {'created_week' => k, 'count' => v.size}}
  end
end