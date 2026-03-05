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
      # Supplier Master
      resources :suppliers, only: %i[index show create update destroy] do
        member do
          post :blacklist
          post :activate
        end
        resources :supplier_products, only: %i[index create update destroy],
                  controller: 'supplier_products'
      end

      # Purchase Invoices
      resources :purchase_invoices, only: %i[index show create update] do
        member do
          post :post_invoice, path: 'post'
          post :cancel
        end
      end

      # Stock Transfers
      resources :stock_transfers, only: %i[index show create update] do
        member do
          post :dispatch_transfer, path: 'dispatch'
          post :receive
          post :cancel
        end
      end

      # Inventory Ledger
      resources :inventory_levels, only: %i[index show]   # legacy — kept for existing clients

      namespace :inventory do
        resources :balances,    only: %i[index show]
        resources :movements,   only: %i[index]
        resources :adjustments, only: %i[create]
      end

      resources :routes,          only: %i[index show create update destroy]

      # -- Beat Planning and Retailer Visits (SFA) --------------------------
      resources :beats, only: %i[index show create update] do
        resources :schedules, only: %i[index show create update],
                              controller: 'beat_schedules' do
          member do
            get  :retailers
            post :bulk_upsert
          end
        end
      end

      scope :visits do
        get  'today',    to: 'visits#today'
        get  '',         to: 'visits#index',    as: :visits
        post 'checkin',  to: 'visits#checkin'
        post 'skip_new', to: 'visits#skip_new'
        post ':id/checkout', to: 'visits#checkout', as: :visit_checkout
        post ':id/skip',     to: 'visits#skip',     as: :visit_skip
      end

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

      # Returns Engine
      resources :return_requests, only: %i[index show create update] do
        member do
          post :submit
          post :start_qc
          post :complete_qc
          post :cancel
        end
      end

      resources :credit_notes, only: %i[index show] do
        member do
          post :void_note, path: 'void'
        end
        collection do
          post 'from_return/:return_request_id/issue', action: :issue, as: :issue_from_return
        end
      end

      # Sales Invoices
      resources :sales_invoices, only: %i[index show create] do
        member do
          post :issue
          post :void_invoice, path: 'void'
          get  :pdf
        end
        collection do
          post 'generate_from_order/:sales_order_id', action: :generate_from_order,       as: :generate_invoice_from_order
          post 'generate_from_delivery_stop/:stop_id', action: :generate_from_delivery_stop, as: :generate_invoice_from_stop
        end
      end


      # Payments / Collections
      resources :payments, only: %i[index show create] do
        member do
          post :confirm
          post :reverse
        end
      end

      resources :advance_payments, only: %i[index show] do
        member do
          post :apply
          post :refund
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

      # -- Trade Promotions / Scheme Engine ------------------------------------
      resources :schemes, only: %i[index show create update destroy] do
        collection { get :stats }
      end

      # -- Order Pricing (price preview with schemes) -------------------------
      post 'order_pricing/preview', to: 'order_pricing#preview'

      # -- Analytics / Insights -----------------------------------------------
      scope :analytics, controller: :analytics do
        get :overview,          action: :overview
        get :sales,             action: :sales
        get :collections,       action: :collections
        get 'collections/export', action: :collections_csv
        get :credit_risk,       action: :credit_risk
        get :beat_performance,  action: :beat_performance
        get :inventory_health,  action: :inventory_health
      end
    end
  end
end


