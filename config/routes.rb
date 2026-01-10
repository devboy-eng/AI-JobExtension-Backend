Rails.application.routes.draw do
  # Root route
  root to: proc { [200, {}, ['AI Job Extension Backend API']] }
  
  # API routes for Chrome extension
  scope '/api' do
    # Profile routes
    get 'profile', to: 'auth#profile'
    post 'profile', to: 'auth#update_profile'

    # Resume parsing routes
    post 'parse-resume', to: 'auth#parse_resume'

    # Coin management routes
    get 'coins/balance', to: 'auth#coin_balance'
    get 'coins/transactions', to: 'auth#coin_transactions'
    patch 'coins/balance', to: 'auth#update_coin_balance'

    # API v1 routes
    namespace :v1 do
      get 'coins/balance', to: 'coins#balance'
      get 'coins/transactions', to: 'coins#transactions'
    end
    
    # Payment routes (Razorpay)
    post 'payments/create-order', to: 'payments#create_order'
    get 'payments/get-order/:id', to: 'payments#get_order'
    post 'payments/verify', to: 'payments#verify_payment'
    post 'payments/webhook', to: 'payments#webhook'
    get 'payments/history', to: 'payments#history'
    get 'payments/test', to: 'payments#test_razorpay'
    
    # Customization history routes
    get 'customization-history', to: 'auth#get_customization_history'
    post 'customization-history', to: 'auth#save_customization_history'
    delete 'customization-history/:id', to: 'auth#delete_customization_history'
    get 'customization-history/:id/pdf', to: 'auth#download_history_pdf'
    
    # Download routes
    post 'download/pdf', to: 'auth#download_pdf'
    post 'download/doc', to: 'auth#download_doc'
    
    # Auth routes 
    post 'auth/signup', to: 'auth#create'
    post 'auth/login', to: 'auth#login'
    get 'auth/profile', to: 'auth#profile'
  end

  # AI customization routes (outside API namespace)
  post '/api/ai/customize', to: 'ai#customize'
  post '/api/ai/ats-score', to: 'ai#ats_score'
  get '/api/ai/test', to: 'ai#test_ai'
  get '/api/ai/ping', to: 'ai#ping_openai'
  get '/api/ai/simple-test', to: 'ai#simple_test'

  # Authentication routes
  post '/auth/register', to: 'auth#create'
  post '/auth/login', to: 'auth#login'
  delete '/auth/logout', to: 'auth#logout'
  get '/auth/me', to: 'auth#me'
  
  # Job Extension Admin Panel Routes
  get '/simple-admin', to: 'admin#login'
  get '/simple-admin/login', to: 'admin#login', as: 'simple_admin_login'
  post '/simple-admin/authenticate', to: 'admin#authenticate', as: 'simple_admin_authenticate'
  get '/simple-admin/logout', to: 'admin#logout', as: 'simple_admin_logout'
  get '/simple-admin/dashboard', to: 'admin#dashboard', as: 'simple_admin_dashboard'
  get '/simple-admin/users', to: 'admin#users', as: 'simple_admin_users'
  get '/simple-admin/users/:id/coins', to: 'admin#user_coins', as: 'simple_admin_user_coins'
  post '/simple-admin/users/:id/add_coins', to: 'admin#add_coins', as: 'simple_admin_add_coins'
  
  # Job Extension testing endpoints
  post '/test/add-coins', to: 'application#add_test_coins'
  get '/test/admin-check', to: 'application#admin_check'
  get '/test/simple-admin', to: 'application#simple_admin_test'
  
  # Health check
  get '/health', to: 'application#health'
  get '/db-status', to: 'application#db_status'
  get '/debug/env', to: 'application#debug_env'
  
end