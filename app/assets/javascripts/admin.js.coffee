jQuery ($) ->
  chart_box = $('#stat-chart')
  return false if chart_box.length == 0

  console.log chart_box.data('matched')
  series = [
    {name: 'Managed', data: chart_box.data('matched')}
#    {name: 'Managed', data: [
#      [Date.UTC(1970, 9, 21), 0],
#      [Date.UTC(1970, 10, 4), 0.28],
#      [Date.UTC(1970, 10, 9), 0.25],
#      [Date.UTC(1970, 10, 27), 0.2],
#      [Date.UTC(1970, 11, 2), 0.28],
#      [Date.UTC(1970, 11, 26), 0.28],
#      [Date.UTC(1970, 11, 29), 0.47],
#      [Date.UTC(1971, 0, 11), 0.79],
#      [Date.UTC(1971, 0, 26), 0.72],
#      [Date.UTC(1971, 1, 3), 1.02],
#      [Date.UTC(1971, 1, 11), 1.12],
#      [Date.UTC(1971, 1, 25), 1.2],
#      [Date.UTC(1971, 2, 11), 1.18],
#      [Date.UTC(1971, 3, 11), 1.19],
#      [Date.UTC(1971, 4, 1), 1.85],
#      [Date.UTC(1971, 4, 5), 2.22],
#      [Date.UTC(1971, 4, 19), 1.15],
#      [Date.UTC(1971, 5, 3), 0]
#    ]}
  ]

  console.log series

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