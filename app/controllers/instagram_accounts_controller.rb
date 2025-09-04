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
      
      # Step 1: Exchange code for Facebook access token (Instagram Business API)
      response = Faraday.post("https://graph.facebook.com/v18.0/oauth/access_token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = {
          client_id: ENV['FACEBOOK_APP_ID'],
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
      facebook_token = token_data['access_token']
      expires_in = token_data['expires_in'] || 7200 # 2 hours default for Facebook tokens
      
      # Step 2: Get Instagram Business Accounts from Facebook Pages
      pages_response = Faraday.get("https://graph.facebook.com/v18.0/me/accounts") do |req|
        req.params = {
          fields: 'id,name,instagram_business_account{id,username,name,profile_picture_url,followers_count}',
          access_token: facebook_token
        }
      end
      
      instagram_account = nil
      if pages_response.success?
        pages_data = JSON.parse(pages_response.body)
        # Find the Instagram Business Account (matching your user ID: 24259081400439109)
        pages_data['data']&.each do |page|
          if page['instagram_business_account']
            ig_account = page['instagram_business_account']
            # Check if this matches your Instagram Business Account ID
            if ig_account['id'] == '24259081400439109'
              instagram_account = ig_account
              instagram_account['page_name'] = page['name']
              break
            end
          end
        end
      end
      
      if instagram_account.nil?
        return render json: { 
          error: 'Instagram Business Account not found',
          message: 'Expected Instagram Business Account ID: 24259081400439109 not found in your Facebook Pages'
        }, status: :unprocessable_entity
      end
      
      # Step 3: Use the Instagram Business Account data directly
      profile_data = {
        'id' => instagram_account['id'],
        'username' => instagram_account['username'],
        'name' => instagram_account['name'],
        'account_type' => 'BUSINESS',
        'profile_picture_url' => instagram_account['profile_picture_url'],
        'followers_count' => instagram_account['followers_count']
      }
      
      # Skip profile_response check since we already have the data
      Rails.logger.info "Found Instagram Business Account: #{profile_data['username']} (ID: #{profile_data['id']})"
        
        # Create or update Instagram account
        account = current_user.instagram_accounts.find_or_initialize_by(
          instagram_user_id: profile_data['id'].to_s
        )
        
        account.assign_attributes(
          username: profile_data['username'],
          access_token: facebook_token, # Store Facebook token for Instagram Business API access
          account_type: 'BUSINESS',
          media_count: 0, # Will be updated when we fetch media
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