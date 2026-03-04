Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # Devise routes (web sessions)
  devise_for :users, skip: [:sessions, :passwords, :registrations]
  
  # Web session routes
  devise_scope :user do
    get    'login',  to: 'sessions#new',     as: :new_user_session
    post   'login',  to: 'sessions#create',  as: :user_session
    delete 'logout', to: 'sessions#destroy', as: :destroy_user_session
  end

  namespace :api do
    namespace :v1 do
      # API Auth (JWT)
      post   'auth/login',   to: 'auth#login'
      delete 'auth/logout',  to: 'auth#logout'
      post   'auth/refresh', to: 'auth#refresh'

      # Signup flow
      post 'signup/initiate',     to: 'signup#initiate'
      post 'signup/verify_otp',   to: 'signup#verify_otp'
      post 'signup/set_password', to: 'signup#set_password'
      post 'signup/org_details',  to: 'signup#org_details'
      post 'signup/first_branch', to: 'signup#first_branch'
      post 'signup/choose_plan',  to: 'signup#choose_plan'

      # Password reset
      post 'passwords/forgot',       to: 'passwords#forgot'
      post 'passwords/reset',        to: 'passwords#reset'
      post 'passwords/validate_token', to: 'passwords#validate_token'

      # Onboarding
      post 'onboarding/create',    to: 'onboarding#create'
      get  'onboarding',               to: 'onboarding#show'
      post 'onboarding/setup',         to: 'onboarding#setup'
      post 'onboarding/complete_step', to: 'onboarding#complete_step'

      # Current user profile
      get 'profile', to: 'profiles#show'
      put 'profile', to: 'profiles#update'

      # Resources
      resources :organizations, only: %i[index show create update] do
        member do
          get   :settings
          patch :settings, action: :update_settings
        end
      end

      resources :branches, only: %i[index show create update] do
        member do
          get   :settings
          patch :settings, action: :update_settings
        end
      end

      resources :users, only: %i[index show create update] do
        member do
          post :deactivate
        end
        collection do
          post :invite
        end
      end

      resources :memberships, only: %i[index create destroy]
      resources :roles,       only: %i[index]

      resources :invitations, only: %i[index create destroy] do
        collection do
          post :accept
        end
      end
    end
  end
end
