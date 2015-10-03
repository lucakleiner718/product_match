jQuery ($) ->
  $('.select-action').on
    'ajax:success': ->
      window.location.reload()

  $('[data-toggle="popover"]').popover()

  if $('.statistic-table').length == 1
    table = $('.statistic-table')

    get_row = ->
      $('tbody tr', table).each ->
        tr = this
        unless $(this).data('grabbed')
          $.getJSON "/products/statistic_brand?brand=#{$(this).data('brand')}", (resp) ->
            $.each resp, (k,v) ->
              tr.innerHTML = tr.innerHTML.replace("{{#{k}}}", v)
            $(tr).removeClass('hide')
            $('[data-toggle="popover"]', tr).popover()
            $(tr).data('grabbed', true)
            get_row()

          return false

    get_row()