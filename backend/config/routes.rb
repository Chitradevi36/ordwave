Rails.application.routes.draw do
  require 'sidekiq/web'
  # API mode has no session middleware — add it directly to Sidekiq::Web
  Sidekiq::Web.use ActionDispatch::Cookies
  Sidekiq::Web.use ActionDispatch::Session::CookieStore, key: '_orderlane_sidekiq'
  # Protect the Sidekiq dashboard with HTTP Basic Auth
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    username == ENV.fetch('SIDEKIQ_USER', 'admin') &&
      ActiveSupport::SecurityUtils.secure_compare(
        password, ENV.fetch('SIDEKIQ_PASSWORD', 'changeme')
      )
  end
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
      post 'onboarding/quick_create_customer', to: 'onboarding#quick_create_customer'
      post 'onboarding/quick_create_product', to: 'onboarding#quick_create_product'

      # Current user profile (both singular and plural path accepted)
      get  'profile',                  to: 'profiles#show'
      put  'profile',                  to: 'profiles#update'
      post 'profile/change_password',  to: 'profiles#change_password'
      get  'profiles',                 to: 'profiles#show'
      put  'profiles',                 to: 'profiles#update'
      post 'profiles/change_password', to: 'profiles#change_password'

      # Resources
      resources :organizations, only: %i[index show create update] do
        member do
          get   :settings
          patch :settings, action: :update_settings
          get   :plan_info
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
          get  :timeline
          # Credit Intelligence Engine
          get  'risk_profile',            to: 'retailer_risk#show'
          post 'risk_profile/recompute',  to: 'retailer_risk#recompute'
        end
      end

      # Credit Intelligence — batch/aggregate endpoints
      namespace :credit do
        namespace :risk do
          get :riskiest, to: 'retailer_risk#riskiest', controller: '/api/v1/retailer_risk'
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
      resources :inventory_levels, only: %i[index show]   # legacy � kept for existing clients

      namespace :inventory do
        resources :balances,    only: %i[index show]
        resources :movements,   only: %i[index]
        resources :adjustments, only: %i[create]
        post 'check_low_stock', to: 'inventory/alerts#check_low_stock'
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
          get  :validate
          post :accept_with_signup
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
          post :pick
          post :confirm_pick
          post :detect_shortage
          post :resolve_shortage
          get  :lifecycle
          get  :trip_assignment_suggestions
          post :assign_to_trip
        end
      end

      # Pick Lists (warehouse fulfillment)
      resources :pick_lists, only: %i[index show] do
        member do
          post :start
          post :complete
          patch 'items/:item_id', to: 'pick_lists#update_item', as: :update_item
        end
      end

      # Delta Sync + Offline Push
      namespace :sync do
        get  :delta
        post :push
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
          post :apply
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
          post :einvoice
          post :ewaybill
          post :cancel_ewaybill
        end
        collection do
          post 'generate_from_order/:sales_order_id', action: :generate_from_order,       as: :generate_invoice_from_order
          post 'generate_from_delivery_stop/:stop_id', action: :generate_from_delivery_stop, as: :generate_invoice_from_stop
          post :bulk_generate
          get  'bulk_status/:session_id', action: :bulk_status
        end
      end

      # Invoice Generation Quarantine (Failed Invoices)
      resources :invoice_quarantines, only: %i[index show] do
        member do
          post :reprocess
          post :mark_resolved
        end
        collection do
          get :stats
        end
      end

      # Payments / Collections
      resources :payments, only: %i[index show create] do
        collection do
          get :auto_posting_status
          get :audit_trail
          get :auto_post_stats
        end
        member do
          post :confirm
          post :reverse
          post :retry
          post :reject_auto_post
          get :confidence_breakdown
        end
      end

      resources :advance_payments, only: %i[index show] do
        member do
          post :apply
          post :refund
        end
      end

      # Collection Schedules
      resources :collection_schedules, only: %i[index show create update] do
        member do
          post :complete
          post :skip
          post :reschedule
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
          post :optimize
          get  :summary
          # ── Maps & Route Optimization ──────────────────────────────────────────
          post :optimize_trip, path: 'optimize_trip'
          post :calculate_distances, path: 'distances'
          get  :get_directions, path: 'directions'
          post :calculate_eta, path: 'eta'
          post :geocode_address, path: 'geocode'
          get  :reverse_geocode, path: 'reverse_geocode'
          post :validate_address, path: 'validate_address'
        end
        resources :trip_stops, only: %i[index show] do
          member do
            post :complete
            post :send_otp, to: 'delivery_otp#send_otp'
            post :verify_otp, to: 'delivery_otp#verify_otp'
          end
          resources :rejections, only: %i[create], controller: 'stop_rejections'
        end
      end

      resources :delivery_exceptions, only: %i[index]
      resources :delivery_rejections, only: %i[index]

      # -- Trade Promotions / Scheme Engine ------------------------------------
      resources :schemes, only: %i[index show create update destroy] do
        collection do
          get :stats
          get :by_product   # ?product_id=X
        end
      end

      # -- Order Pricing (price preview with schemes) -------------------------
      post 'order_pricing/preview', to: 'order_pricing#preview'

      # -- Notifications -------------------------------------------------------
      resources :notifications, only: %i[index destroy] do
        collection do
          post :read_all
        end
        member do
          patch :read
        end
      end

      # -- Approvals Inbox ---------------------------------------------------
      resources :approvals, only: %i[index]

      # -- Audit Logs -------------------------------------------------------
      resources :audit_logs, only: %i[index]

      # -- Owner Dashboard -------------------------------------------------------
      get 'dashboard', to: 'dashboard#show'

      # -- Analytics / Insights -----------------------------------------------
      scope :analytics, controller: :analytics do
        get :overview,            action: :overview
        get :sales,               action: :sales
        get :collections,         action: :collections
        get 'collections/export', action: :collections_csv
        # credit_risk now enriched from RetailerRiskSnapshot; legacy endpoint kept
        get :credit_risk,         action: :credit_risk
        get :beat_performance,  action: :beat_performance
        get :inventory_health,  action: :inventory_health
        get :returns,           action: :returns
        get :schemes,           action: :schemes
      end

      # -- Reports (downloadable) --------------------------------------------
      scope :reports, controller: :reports do
        get :sales_summary
        get :collection_summary
        get :product_performance
        get :customer_outstanding
        get :sales_rep_performance
        get :delivery_performance
        get :ageing_report
      end

      # -- Supplier Debit Notes ------------------------------------------------
      resources :supplier_debit_notes, only: %i[index show create update] do
        member do
          post :issue
          post :void_note, path: 'void'
        end
      end

      # -- Financial Years ----------------------------------------------------
      resources :financial_years, only: %i[index show create] do
        member do
          post :lock_gst
          post :close
          get  :checklist
        end
      end

      # -- Compliance / GST ---------------------------------------------------
      namespace :compliance do
        # GSTR-1 (export, preview, generate, amendments)
        scope :gstr1, controller: :gstr1 do
          get  :preview
          get  :export
          get  :export_records
          post :generate
          get  :amendments
          post :detect_amendments
        end

        # GST Return Periods (lifecycle management)
        resources :gst_periods, controller: 'gst_periods', only: %i[index show] do
          member do
            post :review
            post :lock
            post :file
            post :reopen
          end
        end

        # GSTR-2B import and reconciliation
        scope :gstr2b, controller: :gstr2b do
          get  :imports
          post :import
          get  'imports/:id',       action: :show_import
          get  'imports/:id/lines', action: :lines
        end

        # GSTR-3B computation
        scope :gstr3b, controller: :gstr3b do
          post :generate
          get  :show
          get  :variance
        end

        # Reconciliation issues
        scope :reconciliation, controller: :reconciliation do
          get  :issues
          get  :summary
          post :run
          post 'issues/:id/resolve',     action: :resolve
          post 'issues/:id/acknowledge', action: :acknowledge
          post 'issues/:id/ignore',      action: :ignore
        end
      end

      # -- Webhooks -----------------------------------------------------------
      resources :webhook_endpoints, only: %i[index show create update destroy] do
        member { post :test }
      end

      # -- Exports ------------------------------------------------------------
      resources :exports, only: %i[index create show]

      # -- Device Tokens (Push Notifications) ---------------------------------
      resources :device_tokens, only: %i[create destroy]

      # -- Bank Reconciliation -----------------------------------------------
      resources :bank_accounts, only: %i[index show create update]

      resources :bank_statement_imports, only: %i[index show create]

      resources :bank_transactions, only: %i[index show] do
        collection do
          get :dashboard
          get :queue
        end
        member do
          post :confirm_match
          post :quick_assign
          post :mark_as_advance
          post :ignore
          post :retry_match
        end
      end

      # -- Accounting Integration ------------------------------------------
      namespace :accounting do
        resources :integrations, only: %i[index show create update] do
          member do
            post :test_configuration
            post :mark_connected
            post :mark_disconnected
            get :agents
            get :queue_stats
          end
          resources :mappings, only: %i[index create update destroy]
        end
        resources :sync_records, only: %i[index show] do
          member { post :retry }
        end
        resources :export_files, only: %i[index show create] do
          member { get :download_url }
        end

        # Agent communication endpoints (Phase 2)
        namespace :agent do
          post :register
          post :heartbeat
          get :poll
          post 'ack/:id', to: 'agent#ack'
          post 'fail/:id', to: 'agent#fail'
          post :push_from_tally
        end
      end

      # -- Billing (Razorpay) ------------------------------------------------
      get  'billing/subscription',         to: 'billing#subscription'
      post 'billing/checkout',             to: 'billing#checkout'
      post 'billing/cancel',               to: 'billing#cancel'
      get  'billing/invoices',             to: 'billing#invoices'
      # Razorpay webhook — no JWT auth, verified via HMAC signature
      post 'billing/webhooks/razorpay',    to: 'webhooks/razorpay#receive'

      # -- Twilio Webhooks ---------------------------------------------------
      # Feature 10: SMS reply webhook from Twilio (incoming customer messages)
      post 'webhooks/twilio/sms_reply',    to: 'webhooks/twilio#sms_reply'

      # -- Document Generation -----------------------------------------------
      resources :documents, only: %i[index show] do
        collection do
          post :generate
          post :batch_generate
          get  :statistics
        end
        member do
          get  :download
          patch :regenerate
          delete :archive, path: 'archive'
        end
      end
    end

    namespace :v2 do
      # API v2 -- opt-in via Accept-Version: v2 header (enforced in Api::V2::BaseController).
      # Add v2-specific resource overrides here. See docs/ARCHITECTURE_OVERVIEW.md.
    end
  end

  # -- Health check (unauthenticated) --------------------------------------
  get "/health", to: "api/v1/health#show"
end
