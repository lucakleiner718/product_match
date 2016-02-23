jQuery ($) ->
  $('.brand-duplicate-decision').on
    'ajax:success': () ->
      $(this).closest('tr').remove()