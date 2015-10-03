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
          $.getJSON "/products/statistic_brand?brand_id=#{$(this).data('id')}", (resp) ->
            $.each resp, (k,v) ->
              tr.innerHTML = tr.innerHTML.replace("{{#{k}}}", v)

            $(tr).removeClass('hide').data('grabbed', true)
            $('[data-toggle="popover"]', tr).popover()
            get_row()

          return false

    get_row()