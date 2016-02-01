Rails.application.routes.draw do

  devise_for :users#, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  root to: 'products#root'
  resources :products, only: [:index, :show] do
    collection do
      get :export, action: :index_export, as: :export
      get :statistic, actino: :statistic, as: :statistic
      get 'statistic/export', acition: :statistic_export, as: :statistic_export
      # get 'products/statistic_brand' => 'products#statistic_brand', as: :products_statistic_brand
      get :selected
      get 'selected/export', action: :selected_export, as: :selected_export
      get :active
      get 'active/:id' => 'products#active_show', as: :active_show
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
