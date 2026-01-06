Rails.application.routes.draw do
  # Root route
  root to: proc { [200, {}, ['AI Job Extension Backend API']] }
  
  # API routes for Chrome extension
  namespace :api do
    namespace :auth do
      post 'signup', to: '/auth#create'
      post 'login', to: '/auth#login'
      get 'profile', to: '/auth#profile'
    end
    
    # Profile routes
    get 'profile', to: '/auth#profile'
    post 'profile', to: '/auth#update_profile'
    
    # Resume parsing routes
    post 'parse-resume', to: '/auth#parse_resume'
    
    # AI customization routes
    namespace :ai do
      post 'customize', to: '/auth#customize_resume'
    end
    
    # Download routes
    namespace :download do
      post 'pdf', to: '/auth#download_pdf'
      post 'doc', to: '/auth#download_doc'
    end
    
    # Coin management routes
    namespace :coins do
      get 'balance', to: '/auth#coin_balance'
      get 'transactions', to: '/auth#coin_transactions'
      patch 'balance', to: '/auth#update_coin_balance'
    end
    
    # Customization history routes
    get 'customization-history', to: '/auth#get_customization_history'
    post 'customization-history', to: '/auth#save_customization_history'
    delete 'customization-history/:id', to: '/auth#delete_customization_history'
    get 'customization-history/:id/pdf', to: '/auth#download_history_pdf'
  end

  # Authentication routes
  post '/auth/register', to: 'auth#create'
  post '/auth/login', to: 'auth#login'
  delete '/auth/logout', to: 'auth#logout'
  get '/auth/me', to: 'auth#me'
  
  # Instagram accounts
  resources :instagram_accounts, only: [:index, :show, :create, :destroy] do
    collection do
      post 'connect'
    end
  end
  
  # Automations
  resources :automations
  
  # Contacts
  resources :contacts, only: [:index, :create, :destroy]
  
  # Dashboard
  get '/dashboard/stats', to: 'dashboard#stats'
  
  # Usage metrics
  get '/usage', to: 'usage#index'
  
  # Referral system
  get '/profile', to: 'auth#profile'
  get '/referral-stats', to: 'referrals#stats'
  get '/referrals', to: 'referrals#index'
  
  # Admin routes
  namespace :admin do
    # Admin authentication
    post '/auth/login', to: 'auth#login'
    delete '/auth/logout', to: 'auth#logout'
    get '/auth/me', to: 'auth#me'
    post '/auth/refresh', to: 'auth#refresh'
    
    # Admin dashboard
    get '/dashboard', to: 'dashboard#index'
    get '/dashboard/stats', to: 'dashboard#stats'
    get '/dashboard/charts', to: 'dashboard#charts'
    get '/dashboard/recent_activity', to: 'dashboard#recent_activity'
    
    # User management
    resources :users, only: [:index, :show, :create, :update, :destroy] do
      member do
        patch 'suspend'
        patch 'activate'
        patch 'change_plan'
        get 'activity_logs'
        post 'send_notification'
      end
      collection do
        get 'export'
        get 'search'
        get 'analytics'
      end
    end
    
    # Role and permission management
    resources :roles do
      member do
        patch 'activate'
        patch 'deactivate'
      end
      resources :permissions, only: [:index, :create, :destroy], controller: 'role_permissions'
    end
    
    resources :permissions, only: [:index, :show]
    
    # Analytics
    resources :analytics, only: [:index] do
      collection do
        get 'users'
        get 'instagram_accounts'
        get 'automations'
        get 'usage_metrics'
        get 'revenue'
        get 'export'
      end
    end
    
    # Settings management
    resources :settings, only: [:index] do
      collection do
        patch 'update'
        patch 'bulk_update'
        patch 'reset_to_defaults'
        get 'export'
        post 'import'
      end
    end
    
    # Instagram account management
    resources :instagram_accounts, only: [:index, :show, :update, :destroy] do
      member do
        patch 'verify'
        patch 'suspend'
        patch 'activate'
      end
      collection do
        get 'search'
        get 'analytics'
        get 'export'
      end
    end
    
    # Automation management
    resources :automations, only: [:index, :show, :update, :destroy] do
      member do
        patch 'start'
        patch 'stop'
        patch 'pause'
        patch 'resume'
      end
      collection do
        get 'search'
        get 'analytics'
        get 'export'
      end
    end
    
    # Contact management
    resources :contacts, only: [:index, :show, :update, :destroy] do
      collection do
        get 'search'
        get 'export'
        post 'import'
        patch 'bulk_update'
        delete 'bulk_destroy'
      end
    end
    
    # Usage metrics
    resources :usage_metrics, only: [:index, :show, :destroy] do
      collection do
        get 'analytics'
        get 'export'
        get 'real_time'
      end
    end
    
    # Admin user management
    resources :admin_users, except: [:show] do
      member do
        patch 'activate'
        patch 'deactivate'
        patch 'change_role'
        patch 'reset_password'
      end
      collection do
        get 'search'
      end
    end
    
    # Audit logs
    resources :admin_logs, only: [:index, :show] do
      collection do
        get 'export'
        get 'search'
      end
    end
    
    resources :user_logs, only: [:index, :show] do
      collection do
        get 'export'
        get 'search'
      end
    end
    
    # System management
    namespace :system do
      get 'status'
      get 'health'
      post 'maintenance_mode'
      post 'clear_cache'
      post 'backup'
      get 'logs'
    end
    
    # Reports
    namespace :reports do
      get 'user_activity'
      get 'revenue'
      get 'usage'
      get 'performance'
      get 'security'
      post 'generate'
      get 'download/:id', to: 'base#download'
    end
  end
  
  # Instagram testing endpoints (development only)
  if Rails.env.development?
    get '/debug/instagram/config', to: 'instagram_test#debug_config'
    get '/debug/instagram/setup-guide', to: 'instagram_test#setup_guide'
    get '/debug/instagram/validate', to: 'instagram_test#validate_oauth_url'
    get '/test/instagram/config', to: 'instagram_test#test_config'
    post '/test/instagram/token', to: 'instagram_test#test_token_exchange'
  end
  
  # Health check
  get '/health', to: 'application#health'
end