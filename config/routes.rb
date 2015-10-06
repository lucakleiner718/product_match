Rails.application.routes.draw do

  devise_for :users#, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  root to: 'products#root'
  get 'products' => 'products#index', as: :products
  get 'match' => 'products#match', as: :match
  post 'match/:product_id' => 'products#match_select', as: :select
  get 'products/statistic' => 'products#statistic', as: :products_statistic
  # get 'products/statistic_brand' => 'products#statistic_brand', as: :products_statistic_brand
  get 'products/statistic/export' => 'products#statistic_export', as: :products_statistic_export
  get 'products/selected' => 'products#selected', as: :products_selected
  get 'products/selected/export' => 'products#selected_export', as: :products_selected_export

  require 'sidekiq/web'
  if Rails.env.production?
    authenticate :user do
      mount Sidekiq::Web, at: "/sidekiq"
    end
  else
    mount Sidekiq::Web, at: "/sidekiq"
  end

end
