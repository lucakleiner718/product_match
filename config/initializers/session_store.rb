# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: '_retailer-products_session', domain: {
  production: 'upc.socialrootdata.com',
  development: 'localhost'
}.fetch(Rails.env.to_sym, :all)
