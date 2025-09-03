class InstagramAccountsController < ApplicationController
  before_action :set_instagram_account, only: [:show, :destroy]
  
  def index
    accounts = current_user.instagram_accounts
    render json: accounts
  end
  
  def show
    render json: @instagram_account
  end
  
  def create
    # Save Instagram tokens from frontend
    account_params = params.require(:instagram_account).permit(
      :instagram_user_id, :username, :access_token, :account_type, :media_count
    )
    
    # Check if account already exists for this user
    existing_account = current_user.instagram_accounts.find_by(
      instagram_user_id: account_params[:instagram_user_id]
    )
    
    if existing_account
      # Update existing account
      if existing_account.update(
        access_token: account_params[:access_token],
        username: account_params[:username],
        account_type: account_params[:account_type],
        media_count: account_params[:media_count],
        token_expires_at: Time.current + 60.days,
        connected_at: Time.current
      )
        render json: existing_account, status: :ok
      else
        render json: { errors: existing_account.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create new account
      account = current_user.instagram_accounts.build(
        instagram_user_id: account_params[:instagram_user_id],
        username: account_params[:username] || 'Unknown',
        access_token: account_params[:access_token],
        account_type: account_params[:account_type] || 'PERSONAL',
        media_count: account_params[:media_count] || 0,
        token_expires_at: Time.current + 60.days,
        connected_at: Time.current
      )
      
      if account.save
        render json: account, status: :created
      else
        render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
  
  def connect
    # Instagram OAuth callback handling for backend token exchange
    code = params[:code]
    
    if code.blank?
      return render json: { error: 'Authorization code is required' }, status: :bad_request
    end
    
    begin
      Rails.logger.info "Starting Instagram OAuth flow with code: #{code[0..8]}..."
      Rails.logger.info "Using client_id: #{ENV['INSTAGRAM_CLIENT_ID']}"
      Rails.logger.info "Using redirect_uri: #{ENV['INSTAGRAM_REDIRECT_URI']}"
      
      # Step 1: Exchange code for short-lived access token using Instagram Basic Display API
      response = Faraday.post("https://api.instagram.com/oauth/access_token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = {
          client_id: ENV['INSTAGRAM_CLIENT_ID'],
          client_secret: ENV['INSTAGRAM_CLIENT_SECRET'],
          grant_type: 'authorization_code',
          redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
          code: code
        }
      end
      
      Rails.logger.info "Instagram API response status: #{response.status}"
      Rails.logger.info "Instagram API response body: #{response.body}"
      
      unless response.success?
        Rails.logger.error "Instagram token exchange failed: #{response.status} - #{response.body}"
        return render json: { 
          error: 'Failed to exchange code for token',
          details: response.body,
          debug_info: {
            client_id: ENV['INSTAGRAM_CLIENT_ID'],
            redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
            code_preview: "#{code[0..8]}..."
          }
        }, status: :unprocessable_entity
      end
      
      token_data = JSON.parse(response.body)
      
      # Step 2: Exchange short-lived token for long-lived token
      long_lived_response = Faraday.get("https://graph.instagram.com/access_token") do |req|
        req.params = {
          grant_type: 'ig_exchange_token',
          client_secret: ENV['INSTAGRAM_CLIENT_SECRET'],
          access_token: token_data['access_token']
        }
      end
      
      if long_lived_response.success?
        long_lived_data = JSON.parse(long_lived_response.body)
        final_token = long_lived_data['access_token']
        expires_in = long_lived_data['expires_in'] || 5184000 # 60 days default
      else
        Rails.logger.warn "Long-lived token exchange failed, using short-lived token"
        final_token = token_data['access_token']
        expires_in = 3600 # 1 hour for short-lived tokens
      end
      
      # Step 3: Get user profile information
      profile_response = Faraday.get("https://graph.instagram.com/me") do |req|
        req.params = {
          fields: 'id,username,account_type,media_count',
          access_token: final_token
        }
      end
      
      if profile_response.success?
        profile_data = JSON.parse(profile_response.body)
        
        # Create or update Instagram account
        account = current_user.instagram_accounts.find_or_initialize_by(
          instagram_user_id: profile_data['id'].to_s
        )
        
        account.assign_attributes(
          username: profile_data['username'],
          access_token: final_token,
          account_type: profile_data['account_type'] || 'PERSONAL',
          media_count: profile_data['media_count'] || 0,
          token_expires_at: Time.current + expires_in.seconds,
          connected_at: Time.current,
          status: 'active'
        )
        
        if account.save
          # Log successful connection
          UserLog.create!(
            user: current_user,
            action: 'instagram_connected',
            details: "Instagram account @#{account.username} connected successfully",
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          
          render json: {
            account: account.as_json(except: [:access_token]),
            message: 'Instagram account connected successfully'
          }, status: :created
        else
          render json: { 
            error: 'Failed to save Instagram account',
            details: account.errors.full_messages 
          }, status: :unprocessable_entity
        end
      else
        render json: { 
          error: 'Failed to fetch Instagram profile',
          details: profile_response.body
        }, status: :unprocessable_entity
      end
      
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      render json: { error: 'Invalid response from Instagram' }, status: :unprocessable_entity
    rescue Faraday::Error => e
      Rails.logger.error "Network error: #{e.message}"
      render json: { error: 'Network error connecting to Instagram' }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
    end
  end
  
  def destroy
    @instagram_account.destroy
    render json: { message: 'Instagram account disconnected' }
  end
  
  private
  
  def set_instagram_account
    @instagram_account = current_user.instagram_accounts.find(params[:id])
  end
end