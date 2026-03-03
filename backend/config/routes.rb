Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  namespace :api do
    namespace :v1 do
      # Auth
      post 'auth/login',  to: 'sessions#create'
      delete 'auth/logout', to: 'sessions#destroy'
      post 'auth/refresh', to: 'sessions#refresh'

      # Resources
      resources :organizations, only: [:index, :show, :create, :update]
      resources :branches, only: [:index, :show, :create, :update]
      resources :users, only: [:index, :show, :create, :update]
      resources :memberships, only: [:index, :create, :destroy]
      resources :roles, only: [:index]
    end
  end
end
