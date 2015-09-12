jQuery ($) ->
  $('.select-action').on
    'ajax:success': ->
      window.location.reload()