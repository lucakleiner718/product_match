jQuery ($) ->
  chart_box = $('#stat-chart')
  return false if chart_box.length == 0

  values = chart_box.data('values')
  series = [
    {name: 'Total products', data: values.total_products}
    {name: 'Total without UPC', data: values.total_without_upc}
    {name: 'Total products published', data: values.total_products_published}
    {name: 'Total without UPC published', data: values.total_without_upc_published}
    {name: 'Added without UPC', data: values.added_without_upc}
    {name: 'Managed', data: values.matched}
  ]

  chart_box.highcharts
    chart:
      type: 'line'
    xAxis:
      type: 'datetime',
      dateTimeLabelFormats:
        month: '%e. %b'
        year: '%b'
    yAxis:
      title: false
    title:
      text: 'Stat Chart'
    series: series
    tooltip:
      shared: true
      headerFormat: '<b>{series.name} {point.x:%Y-%m-%d}</b><br/>'
      crosshairs: true