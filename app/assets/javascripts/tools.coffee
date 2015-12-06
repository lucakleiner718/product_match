jQuery ($) ->
  window.update_current_time = (container) ->
    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    timezoneOffset = parseInt(container.attr('timezone-offset')) / 60 / 60
    int = parseInt(container.attr('datetime'))

    setInterval(->
      int++
      date = new Date(int * 1000);
      tzDifference = timezoneOffset * 60 + date.getTimezoneOffset();
      currentdate = new Date(date.getTime() + tzDifference * 60 * 1000);

      datetime = monthNames[currentdate.getMonth()] + ' ' +
        (if currentdate.getDate() < 10 then '0' else '') +
        currentdate.getDate() + ' ' +
        currentdate.getFullYear() + ' ' +
        currentdate.getHours() + ":" +
        currentdate.getMinutes() + ":" +
        (if currentdate.getSeconds() < 10 then '0' else '') +
        currentdate.getSeconds()

      container.text(datetime)
    , 1000)
