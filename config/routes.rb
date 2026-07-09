Rails.application.routes.draw do
  get "dashboard/index"
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  # Custom sign_out route to handle GET requests
  devise_scope :user do
    get '/users/sign_out' => 'users/sessions#destroy'
  end

  # Root route
  root to: redirect('/admin/customers')

  # Favicon route
  get '/favicon.ico', to: redirect('/icon.png')

  # Public pages
  get 'adhika/privacy-policy', to: 'public_pages#adhika_privacy_policy'
  get 'adhika/account-deletion-policy', to: 'public_pages#adhika_account_deletion_policy'

  # Dashboard
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/beautiful', to: 'dashboard#beautiful'
  get 'dashboard/ultra', to: 'dashboard#ultra'
  get 'dashboard/stats', to: 'dashboard#stats'
  get 'dashboard/card_detail', to: 'dashboard#card_detail'
  get 'dashboard/net_profit', to: 'dashboard#net_profit'
  get 'dashboard/avg_policy_value', to: 'dashboard#avg_policy_value'

  # Ambassador Dashboard
  get 'ambassador/dashboard', to: 'ambassador#dashboard'
  get 'ambassador/commission_details', to: 'ambassador#commission_details'
  get 'ambassador/payout_history', to: 'ambassador#payout_history'

  # Investor Dashboard
  get 'investor/dashboard', to: 'investor#dashboard'
  get 'investor/profit_summary', to: 'investor#profit_summary'
  get 'summary-investor', to: 'investor#profit_summary'

  # Public "apply to onboard your forum" form
  resources :forum_requests, only: [:new, :create]

  # Public, token-based guest pages for the membership funnel — one evolving
  # link sent via WhatsApp that adapts to whatever stage the applicant is at.
  scope :apply, controller: 'public_membership_applications' do
    get  ':token',              action: :show,            as: :public_membership_application
    post ':token/confirm_rsvp', action: :confirm_rsvp,     as: :confirm_rsvp_public_membership_application
    post ':token/feedback',     action: :submit_feedback,  as: :submit_feedback_public_membership_application
    post ':token/interest',     action: :confirm_interest, as: :confirm_interest_public_membership_application
    post ':token/kyc',          action: :submit_kyc,       as: :submit_kyc_public_membership_application
  end

  # Forum/Chapter admin portal (forum_admin + chapter_admin, scoped by role in controllers)
  namespace :forum_portal do
    get 'dashboard', to: 'dashboard#index'
    resources :chapters
    resources :members
    resources :announcements, only: [:index, :new, :create, :destroy]
    resources :events do
      member do
        patch 'registrations/:registration_id/attendance', action: :toggle_attendance, as: :toggle_attendance
        post 'invite_guest'
      end
    end
    resources :membership_applications, path: 'membership', only: [:index, :new, :create, :show] do
      member do
        post :confirm_rsvp
        post :mark_attended
        post :record_feedback
        post :send_join_invite
        post :start_review
        post :approve
        post :reject
        post :mark_paid
        post :convert_to_member
      end
    end
    resources :support_tickets, only: [:index, :show, :create] do
      member { post :reply }
    end
  end

  # Member portal
  namespace :member_portal do
    get 'dashboard', to: 'dashboard#index'
    resources :events, only: [:index, :show] do
      member do
        post :register
        post :mark_attendance
        post :rsvp
      end
    end
    resources :announcements, only: [:index]
    resources :support_tickets, only: [:index, :show, :create] do
      member { post :reply }
    end
  end

  # API routes
  namespace :api do
    resources :cities, only: [:index]
    namespace :v1 do
      # Public API endpoints (no authentication required)
      get 'public/search_sub_agents', to: 'public#search_sub_agents'
      get 'public/sub_agent_details', to: 'public#sub_agent_details'
      get 'public/search_distributors', to: 'public#search_distributors'
      get 'public/insurance_companies', to: 'public#insurance_companies'
      get 'public/motor_insurance_companies', to: 'public#motor_insurance_companies'
    end
  end

  # Admin routes
  namespace :admin do
    # API routes for dashboard modals
    namespace :api do
      resources :policies, only: [] do
        collection do
          get :expiring
          get :expired
          get :processed
          get 'health/expiring', to: 'policies#health_expiring'
          get 'health/expired_month', to: 'policies#health_expired_month'
          get 'health/opportunities', to: 'policies#health_opportunities'
        end
      end

      # System Status API endpoints
      resources :system_status, only: [] do
        collection do
          get :active_affiliates
          get :lead_conversion
          get :avg_policy_value
          get :commissions_due_detailed
        end
      end
    end

    # Admin profile management
    get 'profile', to: 'profile#show'
    get 'profile/edit', to: 'profile#edit', as: 'edit_profile'
    patch 'profile', to: 'profile#update'

    # Analytics
    get 'analytics', to: 'analytics#index'
    post 'analytics/refresh', to: 'analytics#refresh'
    get 'analytics/card_detail', to: 'analytics#card_detail'

    # Document management
    resources :documents do
      member do
        get :download
      end
      collection do
        get 'blob/:key', to: 'documents#blob_access', as: 'blob_access'
        get 'investors/:investor_id/documents/:document_id', to: 'documents#show_investor_document', as: 'show_investor_document'
        get 'investors/:investor_id/documents/:document_id/download', to: 'documents#download_investor_document', as: 'download_investor_document'
        get 'investors/:investor_id/main_document', to: 'documents#show_investor_document', defaults: { type: 'main' }, as: 'show_investor_main_document'
        get 'investors/:investor_id/main_document/download', to: 'documents#download_investor_document', defaults: { type: 'main' }, as: 'download_investor_main_document'
      end
    end

    # Nested document routes for different models
    resources :users do
      resources :documents, except: [:edit, :update]
    end


    resources :customers do
      member do
        get :associations_summary
      end
      resources :documents, controller: 'customer_documents', except: [:edit, :update] do
        member do
          get :download
        end
      end
      resources :uploaded_documents, only: [:destroy]
    end
    resources :payouts do
      member do
        patch :mark_as_paid
        patch :mark_as_processing
        patch :cancel_payout
        get :audit_trail
        get :flow_timeline
      end
      collection do
        get :policies_by_type
        get :commission_receipts
        post :auto_distribute
        get :reports
        get :summary
        get 'policies/:policy_id/actions', action: :policy_actions, as: :policy_actions
      end
    end

    # Commission Tracking System
    resources :commission_tracking, only: [:index, :show, :update] do
      member do
        patch :transfer_to_affiliate
        patch :transfer_to_ambassador
        patch :transfer_to_investor
        patch :transfer_company_expense
        patch :mark_main_agent_commission_received
        patch :settle_distribution_payouts
        get :policy_breakdown
      end
      collection do
        get :dashboard
        get :modern_dashboard
        get :summary
        get :policy_search
        get :search_customers
        post :manual_transfer
        get :commission_details_modal
      end
    end

    # Affiliate Payout System
    resources :affiliate_payouts, only: [:index, :show] do
      collection do
        post :mark_as_paid
        get :unpaid_data
      end
    end

    # Distributor Payout System
    resources :distributor_payouts, only: [:index, :show] do
      collection do
        post :mark_as_paid
        get :unpaid_data
      end
    end

    # Payout 2 System - Comprehensive Payout Management
    resources :payout2, only: [:index] do
      collection do
        patch :mark_as_paid
        get :commission_breakdown
      end
    end

    # Invoice System
    resources :invoices do
      member do
        patch :mark_as_paid
        get :mark_as_paid
        get :download_pdf
        get :show_premium
        get :download_premium_pdf
        get :line_items
      end
      collection do
        post :generate_invoice
      end
    end

    # API endpoints for dashboard and system status
    namespace :api do
      get 'system_status/active_affiliates', to: 'system_status#active_affiliates'
      get 'system_status/lead_conversion', to: 'system_status#lead_conversion'
      get 'system_status/avg_policy_value', to: 'system_status#avg_policy_value'
      get 'system_status/commissions_due_detailed', to: 'system_status#commissions_due_detailed'
      get 'system_status/profit_summary', to: 'system_status#profit_summary'

      # Policy endpoints for modals
      get 'policies/expiring', to: 'policies#expiring'
      get 'policies/expired', to: 'policies#expired'
      get 'policies/processed', to: 'policies#processed'
      get 'policies/health/expiring', to: 'policies#health_expiring'
      get 'policies/health/expired_month', to: 'policies#health_expired_month'
      get 'policies/health/opportunities', to: 'policies#health_opportunities'
    end
    # Users (Admins/Agents) management
    resources :users

    # Roles and Permissions management
    resources :roles do
      member do
        patch :toggle_status
        post :assign_users
      end
      collection do
        get :permissions_preview
      end
    end

    resources :permissions do
      member do
        # Individual permission management
      end
      collection do
        post :generate_defaults
        get :bulk_assign
        post :bulk_update
        get 'module/:module_name', action: :module_permissions, as: :module
      end
    end

    # Sub Agent management (legacy)
    resources :sub_agents do
      collection do
        get :download
      end
      member do
        patch :toggle_status
        patch :deactivate
        patch :activate
        get :distributor
        get :documents
        post :create_missing_payouts
      end
      resources :sub_agent_documents, except: [:show, :index] do
        member do
          delete :destroy_immediate
        end
      end
    end

    # Distributor management
    resources :distributors do
      collection do
        get :download
      end
      member do
        patch :toggle_status
        patch :deactivate
        patch :activate
      end
      resources :distributor_documents, except: [:show, :index] do
        member do
          delete :destroy_immediate
        end
      end
    end

    # Investor management
    resources :investors do
      collection do
        get :investor_summary
      end
      member do
        patch :toggle_status
        get :download_r2_document
        delete :delete_r2_document
        get :summary
      end
      resources :investor_documents, only: [:destroy]
    end

    # R2 File Operations
    namespace :r2 do
      post :upload, to: 'files#upload'
      get :download, to: 'files#download'
      delete :delete, to: 'files#delete'
    end

    # Customer management
    resources :customers do
      collection do
        get :export
        get :download
        get :cities
        get :search_sub_agents
      end
      member do
        patch :toggle_status
        patch :deactivate
        patch :activate
        get :policy_chart
        get :family_members
        get :affiliate_info
        get :nominee_details
        get :trace_commission
        get :product_selection
        get :get_policies
      end
      resources :family_members
    end

    # Insurance management
    resources :policies do
      member do
        get :download_pdf
      end
    end

    # Life Insurance
    resources :life_insurances, path: 'insurance/life' do
      collection do
        get :download
        get :policy_holder_options
        get :customer_family_members
        get :brokers_by_company
        get :agency_codes_by_broker
        get :all_agency_codes
        get :all_brokers
        get :agency_codes_for_broker_type
        get :insurance_companies_for_type
        get :load_customer_nominees
      end
      member do
        get :commission_details
        get :renew
        post :create_renewal
      end
    end

    # Health Insurance Documents
    resources :health_insurance_documents, only: [:destroy] do
      member do
        get :download
      end
    end

    # Health Insurance
    resources :health_insurances, path: 'insurance/health' do
      collection do
        get :download
        get :policy_holder_options
        get :brokers_by_company
        get :agency_codes_by_broker
        get :all_agency_codes
        get :all_brokers
        get :agency_codes_for_broker_type
        get :insurance_companies_for_type
        get :company_name_by_agent
        get :load_customer_nominees
        post :insurance_companies_by_agency
      end
      member do
        get :commission_details
        get :renew
        post :create_renewal
      end
    end

    # Motor Insurance
    resources :motor_insurances, path: 'insurance/motor' do
      collection do
        get :download
        get :customer_family_members
        get :policy_holder_options
        get :customer_affiliate_info
        get :agency_codes_for_broker_type
        get :company_name_by_agent
        get :insurance_companies_for_type
        get :insurance_companies_by_agency
        get :load_customer_nominees
      end
      member do
        get :renew
        post :create_renewal
        delete :delete_document
        post :regenerate_payout
      end
      resources :motor_insurance_documents, path: 'documents', except: [:edit, :update] do
        member do
          get :download
        end
      end
    end

    # Other Insurance
    resources :other_insurances, path: 'insurance/other' do
      collection do
        get :download
        get :all_agency_codes
        get :all_brokers
        get :agency_codes_for_broker_type
        get :insurance_companies_for_type
        get :insurance_companies_by_agency
        get :load_customer_nominees
      end
      member do
        get :renew
        post :create_renewal
        post :regenerate_payout
      end
    end

    # Client Services (Taxation, Loans, Travel, Credit Card)
    resources :client_services

    # Mutual Funds
    resources :mutual_funds, path: 'investments/mutual-funds'

    # Other Insurance - Alternative routes for backward compatibility
    scope :other_insurances, controller: :other_insurances do
      get :all_brokers
      get :insurance_companies_for_type
      get :all_agency_codes
      get :insurance_companies_by_agency
    end

    # Agency/Broker management
    resources :agency_brokers

    # Broker management
    resources :brokers do
      member do
        patch :toggle_status
      end
      collection do
        get :search
      end
      resources :broker_codes, except: [:show]
    end

    # Standalone Broker Codes management (if needed outside broker context)
    resources :broker_codes do
      member do
        patch :toggle_status
      end
      collection do
        get :all_agency_codes
        get :companies_by_agency_code
      end
    end

    # Agency Code management
    resources :agency_codes do
      collection do
        get :search
        get :brokers_for_direct
        get :agents_for_broker
        get :all_agents
        get :companies_for_agent
        get :all_brokers
        get :companies_for_broker
        get :all_companies
        get :companies_by_type
        get :all_codes
        get :agents_for_code
        get :company_for_agency_code
      end
      member do
        get :insurance_companies
      end
    end

    # Insurance companies with API endpoints
    resources :insurance_companies do
      collection do
        get :search      # AJAX search endpoint
        get :statistics  # AJAX statistics endpoint
      end
    end

    # Policy Documents Management
    resources :policy_documents, except: [:edit, :update] do
      member do
        get :download
      end
      collection do
        post :bulk_upload
      end
    end

    # Helpdesk management
    resources :helpdesk, path: 'helpdesk' do
      member do
        patch :update_status
        patch :assign_to
        patch :add_response
      end
      collection do
        get :analytics
        get :tickets
        get :knowledge_base
        get :customer_tickets
      end
    end

    # Client Requests management
    resources :client_requests do
      member do
        patch :update_status
        patch :assign_to
        patch :add_response
      end
      collection do
        get :pending
        get :in_progress
        get :resolved
        get :search
      end
    end

    # Leads management
    resources :leads do
      resources :documents, except: [:edit, :update]
      member do
        get :convert_to_customer
        patch :convert_to_customer
        patch :convert_to_customer_branch_out
        patch :create_policy
        patch :transfer_referral
        patch :advance_stage
        patch :go_back_stage
        patch :update_stage
        patch :convert_stage
        patch :mark_not_interested
        patch :close_lead
      end
      collection do
        get :export
        get :download
        get :statistics
        patch :bulk_update_stage
        get :check_existing_customer
        get :search_sub_agents
        post :branch_out
        post :branch_out_from_customer
        get :kanban
        get :kanban_flow
      end
    end

    # Appointments
    resources :appointments do
      collection do
        get :calendar_data
        get :search_customers
        get :download
      end
    end

    # Banner management
    resources :banners do
      member do
        patch :toggle_status
      end
    end

    # Banner Documents
    resources :banner_documents, only: [:create, :show, :destroy] do
      member do
        get :download
      end
    end

    # Reports namespace
    namespace :reports do
      resources :commission_reports, only: [:index] do
        collection do
          get :export
          get :generate
          post :create_report
          post :preview
          get :saved_reports
        end
        member do
          get :show_saved_report
          delete :destroy_saved_report
          get :export_csv
          get :export_pdf
        end
      end

      # Advanced Commission Reports with enhanced filtering and export options
      resources :commission_reports_advanced, only: [:index] do
        collection do
          get :export_modal
          post :export_pdf
          post :export_excel
          post :export_csv
          get :filter_data
        end
      end

      resources :all_policy_reports, only: [:index, :new, :create, :show, :destroy] do
        collection do
          post :preview
          get :export_csv
          post :export_pdf
        end
        member do
          get :export_csv
        end
      end

      # Profit Reports - Show all policies with profit information
      resources :profit_reports, only: [:index] do
        collection do
          get :export_csv
          get :export_pdf
        end
      end

      resources :lead_reports, only: [:index, :new, :create] do
        collection do
          post :preview
        end
        member do
          get :show_saved_report
          delete :destroy_saved_report
          get :export_csv
        end
      end

      # Session Reports (commented out - NPE)
      # resources :sessions, only: [:index] do
      #   collection do
      #     get :export
      #     post :filter
      #     get :realtime_data
      #     get :active_users_details
      #   end
      # end

      resources :expired_insurance_reports, only: [:index] do
        collection do
          get :export
          get :generate
          post :create_report
          post :preview
          get :saved_reports
          get :export_csv
          post :export_pdf
        end
        member do
          get :show_saved_report
          delete :destroy_saved_report
          get :export_csv
        end
      end
      resources :payment_due_reports, only: [:index] do
        collection do
          get :export
        end
      end
      resources :upcoming_renewal_reports, only: [:index] do
        collection do
          get :export
          get :generate
          post :create_report
          post :preview
          get :saved_reports
        end
        member do
          get :show_saved_report
          delete :destroy_saved_report
          get :export_csv
        end
      end
      resources :upcoming_payment_reports, only: [:index] do
        collection do
          get :export
        end
      end
      resources :leads_reports, only: [:index] do
        collection do
          get :export
        end
      end
      # resources :session_reports, only: [:index] do
      #   collection do
      #     get :export
      #   end
      # end
    end

    # AI Reports
    resources :ai_reports, only: [] do
      collection do
        get :chat_interface
        post :generate
        post :ask
        get :history
      end
    end

    # Import Section
    resources :imports, only: [:index] do
      collection do
        get :customers_form
        get :sub_agents_form
        get :distributors_form
        get :health_insurances_form
        get :life_insurances_form
        get :motor_insurances_form
        get :download_template
        post :customers_preview
        post :sub_agents_preview
        post :distributors_preview
        post :health_insurances_preview
        post :life_insurances_preview
        post :motor_insurances_preview
      end
    end

    # Import/Export
    post 'import/customers', to: 'imports#customers'
    post 'import/sub_agents', to: 'imports#sub_agents'
    post 'import/distributors', to: 'imports#distributors'
    post 'import/health_insurances', to: 'imports#health_insurances'
    post 'import/life_insurances', to: 'imports#life_insurances'
    post 'import/motor_insurances', to: 'imports#motor_insurances'
    post 'import/agencies', to: 'imports#agencies'

    # Commission management for ambassadors/distributors
    resources :commissions, only: [:index] do
      collection do
        get :dashboard
        get :reports
        get :payouts
        get :affiliates
      end
    end

    # Settings namespace
    namespace :settings do
      resources :user_roles do
        member do
          patch :toggle_status
        end
      end

      # System settings (placeholder for future expansion)
      get :system, to: 'system#index'
      patch :system, to: 'system#update'
      put :system, to: 'system#update'
    end

    # Forum platform (super_admin only)
    get 'platform_dashboard', to: 'platform_dashboard#index'
    get 'platform_analytics', to: 'platform_analytics#index'
    get 'platform_reports', to: 'platform_reports#index'
    resources :business_plans
    resources :forums do
      member do
        post :suspend
        post :activate
        patch :update_plan
        post :force_logout_admin
      end
    end
    resources :forum_requests, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end
    resources :platform_announcements, controller: 'announcements' do
      member { post :publish }
    end
    resources :platform_support_tickets, controller: 'support_tickets', only: [:index, :show] do
      member do
        post :reply
        patch :change_status
      end
    end
  end

  # Mobile API routes
  namespace :api do
    namespace :v1 do
      # Authentication APIs (Admin/Web)
      post 'auth/login', to: 'authentication#login'
      post 'auth/register', to: 'authentication#register'
      post 'auth/forgot_password', to: 'authentication#forgot_password'
      post 'auth/reset_password', to: 'authentication#reset_password'

      # Mobile API Routes
      namespace :mobile do
        # Mobile Authentication APIs
        post 'auth/login', to: 'authentication#login'
        post 'auth/register', to: 'authentication#register'
        post 'auth/forgot_password', to: 'authentication#forgot_password'

        # Customer Module APIs
        get 'customer/portfolio', to: 'customer#portfolio'
        get 'customer/upcoming_installments', to: 'customer#upcoming_installments'
        get 'customer/upcoming_renewals', to: 'customer#upcoming_renewals'
        post 'customer/add_policy', to: 'customer#add_policy'

        # Customer Helpdesk APIs
        post 'customer/helpdesk', to: 'customer#create_helpdesk_ticket'
        get 'customer/helpdesk_tickets', to: 'customer#helpdesk_tickets'
        get 'customer/helpdesk_tickets/:id', to: 'customer#helpdesk_ticket_details'

        # Settings Module APIs
        get 'settings/profile', to: 'settings#profile'
        put 'settings/profile', to: 'settings#update_profile'
        post 'settings/change_password', to: 'settings#change_password'
        get 'settings/terms', to: 'settings#terms_and_conditions'
        get 'settings/contact', to: 'settings#contact_us'
        get 'settings/helpdesk', to: 'settings#helpdesk_tickets'
        post 'settings/helpdesk', to: 'settings#helpdesk'
        get 'settings/notifications', to: 'settings#notification_settings'
        put 'settings/notifications', to: 'settings#update_notification_settings'

        # Agent Dashboard APIs
        get 'agent/dashboard', to: 'agent#dashboard'
        get 'agent/customers', to: 'agent#customers'
        post 'agent/customers', to: 'agent#add_customer'
        get 'agent/policies', to: 'agent#policies'
        post 'agent/policies/health', to: 'agent#add_health_policy'
        post 'agent/policies/life', to: 'agent#add_life_policy'
        post 'agent/policies/motor', to: 'agent#add_motor_policy'
        post 'agent/policies/other', to: 'agent#add_other_policy'
        get 'agent/form_data', to: 'agent#form_data'
        get 'agent/insurance_companies', to: 'agent#insurance_companies'
        get 'agent/motor_insurance_companies', to: 'agent#motor_insurance_companies'

        # Leads APIs
        get 'agent/leads', to: 'agent#leads'
        post 'agent/leads', to: 'agent#add_lead'

        # Sub Agent APIs
        get 'sub_agent/leads', to: 'sub_agent#leads'
        get 'sub_agent/leads/:id', to: 'sub_agent#lead_details'
        post 'sub_agent/helpdesk', to: 'sub_agent#create_helpdesk_ticket'
        get 'sub_agent/helpdesk_tickets', to: 'sub_agent#helpdesk_tickets'

        # Sub Agent Notification APIs
        get 'sub_agent/notifications', to: 'sub_agent#notifications'
        put 'sub_agent/notifications/:id/mark_read', to: 'sub_agent#mark_notification_read'
        put 'sub_agent/notifications/mark_all_read', to: 'sub_agent#mark_all_notifications_read'
        get 'sub_agent/notifications/unread_count', to: 'sub_agent#unread_notifications_count'

        # Commission Distribution APIs
        get 'agent/commission_distribution', to: 'agent#commission_distribution'
        get 'agent/commission_summary', to: 'agent#commission_summary'

        # Banner APIs
        resources :banners, only: [:index, :show] do
          collection do
            get :active, to: 'banners#active'
            get :by_location, to: 'banners#by_location'
          end
        end

        # Commission APIs for Sub-Agents/Affiliates
        get 'commission/breakdown', to: 'commission#breakdown'
        get 'commission/summary', to: 'commission#summary'
        get 'commission/history', to: 'commission#history'
        get 'commission/stats', to: 'commission#stats'

        # Commission APIs for Agents (alias routes)
        get 'agent/commission/breakdown', to: 'commission#breakdown'
        get 'agent/commission/summary', to: 'commission#summary'
        get 'agent/commission/history', to: 'commission#history'
        get 'agent/commission/stats', to: 'commission#stats'

        # ── Investment Module APIs (Customer-facing) ─────────────────────────
        get    'investments/summary',             to: 'investments#summary'
        # Mutual Funds
        get    'investments/mutual_funds',         to: 'investments#mutual_funds'
        post   'investments/mutual_funds',         to: 'investments#create_mutual_fund'
        get    'investments/mutual_funds/:id',     to: 'investments#show_mutual_fund'
        patch  'investments/mutual_funds/:id',     to: 'investments#update_mutual_fund'
        delete 'investments/mutual_funds/:id',     to: 'investments#destroy_mutual_fund'
        # Fixed Deposits
        get    'investments/fd',                   to: 'investments#fd_list'
        post   'investments/fd',                   to: 'investments#create_fd'
        get    'investments/fd/:id',               to: 'investments#show_fd'
        patch  'investments/fd/:id',               to: 'investments#update_fd'
        delete 'investments/fd/:id',               to: 'investments#destroy_fd'
        # Other Investments
        get    'investments/other',                to: 'investments#other_list'
        post   'investments/other',                to: 'investments#create_other'
        get    'investments/other/:id',            to: 'investments#show_other'
        patch  'investments/other/:id',            to: 'investments#update_other'
        delete 'investments/other/:id',            to: 'investments#destroy_other'

        # ── Taxation APIs (Customer) ─────────────────────────────────────────
        get    'taxation/summary',                  to: 'taxation#summary'
        get    'taxation/itr',                      to: 'taxation#itr_list'
        post   'taxation/itr',                      to: 'taxation#create_itr'
        get    'taxation/itr/:id',                  to: 'taxation#show_itr'
        patch  'taxation/itr/:id',                  to: 'taxation#update_itr'
        delete 'taxation/itr/:id',                  to: 'taxation#destroy_itr'
        get    'taxation/tax_planning',             to: 'taxation#tax_planning_list'
        post   'taxation/tax_planning',             to: 'taxation#create_tax_planning'
        get    'taxation/tax_planning/:id',         to: 'taxation#show_tax_planning'
        patch  'taxation/tax_planning/:id',         to: 'taxation#update_tax_planning'
        delete 'taxation/tax_planning/:id',         to: 'taxation#destroy_tax_planning'

        # ── Loans APIs (Customer) ────────────────────────────────────────────
        get    'loans/summary',                     to: 'loans#summary'
        get    'loans/personal',                    to: 'loans#personal_list'
        post   'loans/personal',                    to: 'loans#create_personal'
        get    'loans/personal/:id',                to: 'loans#show_personal'
        patch  'loans/personal/:id',                to: 'loans#update_personal'
        delete 'loans/personal/:id',                to: 'loans#destroy_personal'
        get    'loans/home',                        to: 'loans#home_list'
        post   'loans/home',                        to: 'loans#create_home'
        get    'loans/home/:id',                    to: 'loans#show_home'
        patch  'loans/home/:id',                    to: 'loans#update_home'
        delete 'loans/home/:id',                    to: 'loans#destroy_home'
        get    'loans/mortgage',                    to: 'loans#mortgage_list'
        post   'loans/mortgage',                    to: 'loans#create_mortgage'
        get    'loans/mortgage/:id',                to: 'loans#show_mortgage'
        patch  'loans/mortgage/:id',                to: 'loans#update_mortgage'
        delete 'loans/mortgage/:id',                to: 'loans#destroy_mortgage'
        get    'loans/business',                    to: 'loans#business_list'
        post   'loans/business',                    to: 'loans#create_business'
        get    'loans/business/:id',                to: 'loans#show_business'
        patch  'loans/business/:id',                to: 'loans#update_business'
        delete 'loans/business/:id',                to: 'loans#destroy_business'

        # ── Travel APIs (Customer) ───────────────────────────────────────────
        get    'travel/summary',                    to: 'travel#summary'
        get    'travel/domestic',                   to: 'travel#domestic_list'
        post   'travel/domestic',                   to: 'travel#create_domestic'
        get    'travel/domestic/:id',               to: 'travel#show_domestic'
        patch  'travel/domestic/:id',               to: 'travel#update_domestic'
        delete 'travel/domestic/:id',               to: 'travel#destroy_domestic'
        get    'travel/international',              to: 'travel#international_list'
        post   'travel/international',              to: 'travel#create_international'
        get    'travel/international/:id',          to: 'travel#show_international'
        patch  'travel/international/:id',          to: 'travel#update_international'
        delete 'travel/international/:id',          to: 'travel#destroy_international'

        # ── Credit Card APIs (Customer) ──────────────────────────────────────
        get    'credit_cards/summary',              to: 'credit_cards#summary'
        get    'credit_cards/rewards',              to: 'credit_cards#rewards_list'
        post   'credit_cards/rewards',              to: 'credit_cards#create_rewards'
        get    'credit_cards/rewards/:id',          to: 'credit_cards#show_rewards'
        patch  'credit_cards/rewards/:id',          to: 'credit_cards#update_rewards'
        delete 'credit_cards/rewards/:id',          to: 'credit_cards#destroy_rewards'
        get    'credit_cards/business',             to: 'credit_cards#business_list'
        post   'credit_cards/business',             to: 'credit_cards#create_business'
        get    'credit_cards/business/:id',         to: 'credit_cards#show_business'
        patch  'credit_cards/business/:id',         to: 'credit_cards#update_business'
        delete 'credit_cards/business/:id',         to: 'credit_cards#destroy_business'
        get    'credit_cards/travel',               to: 'credit_cards#travel_list'
        post   'credit_cards/travel',               to: 'credit_cards#create_travel'
        get    'credit_cards/travel/:id',           to: 'credit_cards#show_travel'
        patch  'credit_cards/travel/:id',           to: 'credit_cards#update_travel'
        delete 'credit_cards/travel/:id',           to: 'credit_cards#destroy_travel'

        # Client Services APIs (Investments, Taxation, Loans, Travel, Credit Card)
        get  'client_services/form_data',   to: 'client_services#form_data'
        get  'client_services/summary',     to: 'client_services#summary'
        get  'client_services/investments', to: 'client_services#investments'
        get  'client_services/taxation',    to: 'client_services#taxation'
        get  'client_services/loans',       to: 'client_services#loans'
        get  'client_services/travel',      to: 'client_services#travel'
        get  'client_services/credit_card', to: 'client_services#credit_card'
        resources :client_services, only: [:index, :show, :create, :update, :destroy]

        # General Insurance (Other Insurance) APIs
        post 'agent/policies/general', to: 'agent#add_general_policy'
        get  'agent/policies/general',  to: 'agent#general_policies'
      end

      # Sub Agent APIs
      resources :sub_agents do
        member do
          patch :toggle_status
        end
      end

      # Customer APIs
      resources :customers do
        collection do
          post :register
        end
        member do
          patch :toggle_status
        end
      end

      # Health Insurance APIs
      resources :health_insurances do
        collection do
          get :statistics
          get :form_data
          get :policy_holder_options
        end
      end

      # Life Insurance APIs
      resources :life_insurances do
        collection do
          get :statistics
          get :form_data
          get :policy_holder_options
        end
      end

      # Notification APIs
      resources :notifications, only: [:index, :show] do
        member do
          patch :mark_as_read
          patch :mark_as_unread
        end
        collection do
          get :unread_count
          get :recent
          get :types
          patch :mark_all_as_read
        end
      end
    end

    # Policy Documents Management
    resources :policy_documents, except: [:edit, :update] do
      member do
        get :download
      end
      collection do
        get 'for/:policy_type/:policy_id', action: :index, as: :for_policy
      end
    end

  end

  # Favicon route to serve favicon.ico
  get '/favicon.ico' => 'application#favicon'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
