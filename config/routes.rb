Rails.application.routes.draw do

  devise_for :users#, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  root to: 'products#root'
  resources :products, only: [:index, :show] do
    collection do
      get :export, action: :index_export, as: :export
      get :statistic
      get 'statistic/export', action: :statistic_export, as: :statistic_export
      # get 'products/statistic_brand' => 'products#statistic_brand', as: :products_statistic_brand
      get :selected
      get 'selected/export', action: :selected_export, as: :selected_export
      get :active
      get 'active/export' => 'products#active_export', as: :active_export
      get 'active/:id' => 'products#active_show', as: :active_show
      get 'matched' => 'products#matched', as: :matched
    end
  end

  get 'marketing' => 'marketing#index'

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
