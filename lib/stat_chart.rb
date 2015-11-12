class StatChart
  def data
    timeframe = 6.months

    chart = {
      total_products: [],
      total_products_published: [],
      total_without_upc: [],
      total_without_upc_published: [],
      added_without_upc: [],
      matched: []
    }

    stats = StatAmount.where('date > ?', 6.months.ago).where(key: ['shopbop_total', 'not_matched_size', 'shopbop_total_published', 'not_matched_size_published'])
    stats.each do |s|
      item = [s.date.to_time(:utc).to_i*1000, s.value]
      if s.key == 'shopbop_total'
        chart[:total_products] << item
      elsif s.key == 'shopbop_total_published'
        chart[:total_products_published] << item
      elsif s.key == 'not_matched_size'
        chart[:total_without_upc] << item
      elsif s.key == 'not_matched_size_published'
        chart[:total_without_upc_published] << item
      end
    end

    added_without_upc = ProductUpc.connection.execute("
      SELECT count(*), EXTRACT(YEAR FROM created_at)::text || '-' || EXTRACT(WEEK FROM created_at)::text AS created_week
      FROM products
      WHERE source='shopbop' AND (upc is null OR upc = '')
      GROUP BY created_week
    ")
    chart[:added_without_upc] =
      added_without_upc.sort{|a,b| a['created_week'] <=> b['created_week']}
      .map do |el|
        week = el['created_week'].split('-').map(&:to_i)
        [Date.commercial(week.first, week.last, 7).to_time(:utc).to_i*1000, el['count'].to_i]
      end

    matched = ProductUpc.connection.execute("
      SELECT count(*), EXTRACT(YEAR FROM created_at)::text || '-' || EXTRACT(WEEK FROM created_at)::text AS created_week
      FROM product_upcs
      WHERE created_at > '#{timeframe.ago}'
      GROUP BY created_week
    ")
    chart[:matched] =
      matched.sort{|a,b| a['created_week'] <=> b['created_week']}
        .map do |el|
          week = el['created_week'].split('-').map(&:to_i)
          [Date.commercial(week.first, week.last, 7).to_time(:utc).to_i*1000, el['count'].to_i]
        end

    chart
  end
end