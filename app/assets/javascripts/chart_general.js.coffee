#= require highcharts.src
jQuery ($) ->
  chart_boxes = $('.chart-general')
  return false if chart_boxes.length == 0

  chart_boxes.each (index, chart_box) ->
    chart_box = $(chart_box)
    series = chart_box.data('values')

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
        text: chart_box.data('chart-name')
      series: series
      tooltip:
        shared: true
        headerFormat: '<b>{series.name} {point.x:%Y-%m-%d}</b><br/>'
        crosshairs: true