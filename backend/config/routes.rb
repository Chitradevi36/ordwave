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
      get  'profile',                 to: 'profiles#show'
      put  'profile',                 to: 'profiles#update'
      post 'profile/change_password', to: 'profiles#change_password'

      # Resources
      resources :organizations, only: %i[index show create update] do
        member do
          get   :settings
          patch :settings, action: :update_settings
        end
      end

      resources :branches, only: %i[index show create update] do
        collection do
          post :bulk_import
        end
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

      # Customers (Retailer CRM)
      resources :customers, only: %i[index show create update destroy] do
        collection do
          get  :check_duplicate
          post :bulk_import
          get  :sample_csv
          get  :export_csv
        end
        member do
          post :block
          post :unblock
          post :deactivate
          get  :credit_usage
        end
      end
      resources :routes,          only: %i[index show create update destroy]
      resources :credit_accounts, only: %i[show update] do
        member do
          patch :update_flags
        end
        resources :limit_change_requests, only: %i[create],
                  controller: 'credit_limit_change_requests'
      end

      # Credit Engine
      resource  :credit_policy,            only: %i[show update],
                controller: 'credit_policies'
      resources :prepayment_skus,          only: %i[index show create] do
        member do
          post :deactivate
        end
      end
      resources :credit_limit_change_requests, only: %i[index show] do
        member do
          post :decision
        end
      end

      resources :invitations, only: %i[index create destroy] do
        collection do
          post :accept
        end
      end

      # HSN/SAC Master & GST
      resources :hsn_sac_codes, only: %i[index show create update destroy] do
        collection do
          get  :lookup
          post :bulk_import
          get  :sample_csv
          get  :export_csv
        end
        member do
          post :rate_change
        end
      end

      # Product Catalogue
      resources :product_categories, only: %i[index show create update destroy]
      resources :units_of_measure,   only: %i[index show create update destroy]

      resources :products, only: %i[index show create update destroy] do
        collection do
          post :bulk_import
          get  :sample_csv
          get  :export_csv
          get  :generate_sku
        end
        member do
          post :discontinue
          get  :price
        end
      end

      # Price Lists
      resources :price_lists, only: %i[index show create update destroy] do
        member do
          post   :assign
          delete :unassign
          get    :items
        end
        resources :items, only: %i[create update destroy],
                          controller: 'price_list_items' do
          collection do
            post :bulk_import
            get  :sample_csv
            get  :export_csv
          end
        end
      end

      # Sales Orders
      resources :sales_orders, only: %i[index show create update] do
        collection do
          post :from_mobile
          get  :recent_for_customer
        end
        member do
          post :submit
          post :approve
          post :hold
          post :cancel
          post :refresh_price
        end
      end

      # Delivery
      resources :vehicles, only: %i[index show create update destroy]

      resources :delivery_trips, only: %i[index show create update] do
        collection do
          post :auto_create
        end
        member do
          post :dispatch_trip, path: 'dispatch'
          post :cancel
        end
        resources :trip_stops, only: %i[index show] do
          member do
            post :complete
          end
        end
      end

      resources :delivery_exceptions, only: %i[index]
    end
  end
end
