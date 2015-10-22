jQuery ($) ->
  chart_box = $('#stat-chart')
  return false if chart_box.length == 0

  values = chart_box.data('values')
  series = [
    {name: 'Total', data: values.total}
    {name: 'Without UPC', data: values.empty}
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