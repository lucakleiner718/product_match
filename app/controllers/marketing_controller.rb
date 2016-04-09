class MarketingController < ApplicationController
  def index
    chart = StatChart.new.build_data
    @chart_db = [
      {name: 'Total products', data: chart[:total_products]},
      {name: 'Total without UPC', data: chart[:total_without_upc]},
    ]
    @chart_shopbop_file = [
      {name: 'Total products published', data: chart[:total_products_published]},
      {name: 'Total without UPC published', data: chart[:total_without_upc_published]},
    ]
    @chart_matching = [
      {name: 'Added without UPC', data: chart[:added_without_upc]},
      {name: 'Managed', data: chart[:matched]},
    ]

    @links = Dir.glob('public/downloads/shopbop_products_upc-*').map{|el| [Date.strptime(el.match(/shopbop_products_upc-(\d+_\d+_\d+)-/) && $1, '%m_%d_%y'), el]}.sort_by{|el| el[0]}.reverse[0..9].map do |(date, l)|
      [
        l.sub(/^public/, ''),
        date.strftime('%m/%d/%y'),
        Rails.cache.fetch("exported-file-#{date}-#{File.mtime(l)}") { File.readlines(l).size },
        File.mtime(l)
      ]
    end
    @links = [[
        '/downloads/shopbop_products_upc.csv',
        'Current week',
        File.readlines('public/downloads/shopbop_products_upc.csv').size,
        File.mtime('public/downloads/shopbop_products_upc.csv')
      ]] + @links
  end
end
