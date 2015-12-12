Rails.application.routes.draw do

  devise_for :users#, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  root to: 'products#root'
  get 'products' => 'products#index', as: :products
  get 'products/export' => 'products#index_export', as: :products_export

  get 'products/statistic' => 'products#statistic', as: :products_statistic
  # get 'products/statistic_brand' => 'products#statistic_brand', as: :products_statistic_brand
  get 'products/statistic/export' => 'products#statistic_export', as: :products_statistic_export
  get 'products/selected' => 'products#selected', as: :products_selected
  get 'products/selected/export' => 'products#selected_export', as: :products_selected_export
  get 'marketing' => 'products#marketing', as: :marketing

  get 'match' => 'match#show', as: :match
  post 'match/undo' => 'match#undo', as: :match_undo
  post 'match/select/:product_id' => 'match#select', as: :match_select

  require 'sidekiq/web'
  require 'sidekiq/pro/web'
  if Rails.env.production?
    authenticate :user do
      mount Sidekiq::Web, at: "/sidekiq"
    end
  else
    mount Sidekiq::Web, at: "/sidekiq"
  end

end
