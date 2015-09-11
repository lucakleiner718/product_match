jQuery ($) ->
  $('.select-product-found').on
    'ajax:success': ->
      window.location.reload()