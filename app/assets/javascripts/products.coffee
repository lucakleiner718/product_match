jQuery ($) ->
  $('.select-action').on
    'ajax:success': ->
      window.location.reload()

  $('[data-toggle="popover"]').popover()

#  if $('.statistic-table').length == 1
#    table = $('.statistic-table')
#
#    set_data = (tr, data) ->
#      $.each data, (k,v) ->
#        tr.innerHTML = tr.innerHTML.replace("{{#{k}}}", v)
#      $(tr).removeClass('hide').data('grabbed', true)
#      $('[data-toggle="popover"]', tr).popover()
#
#    get_row = ->
#      $('tbody tr', table).each ->
#        tr = this
#        if $(this).data('hash')
#          set_data(tr, $(this).data('hash'))
#        else if !$(this).data('grabbed')
#          $.getJSON "/products/statistic_brand?brand_id=#{$(this).data('id')}", (resp) ->
#            set_data(tr, resp)
#            get_row()
#
#          return false
#
#    get_row()

  $('#filter_brand_id').select2()
