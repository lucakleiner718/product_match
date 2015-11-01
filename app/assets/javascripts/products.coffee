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

  $('.select2').select2()

  $(".match-brand").on 'change', ->
    window.location = "/match?brand_id=" + $(this).val()

  $('.suggestion-images').on 'click', ->
    current = $(this).find('img:visible')
    next = current.next()
    next = $('.suggestion-images img').first() if next.length == 0
    current.css('display', 'none')
    next.css('display', 'block')