Rails.application.routes.draw do
  # Authentication routes
  post '/auth/register', to: 'auth#create'
  post '/auth/login', to: 'auth#login'
  delete '/auth/logout', to: 'auth#logout'
  get '/auth/me', to: 'auth#me'
  
  # Instagram accounts
  resources :instagram_accounts, only: [:index, :show, :create, :destroy]
  
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
  
  # Health check
  get '/health', to: 'application#health'
end