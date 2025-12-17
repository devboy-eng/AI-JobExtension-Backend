class Api::Instagram::InstagramController < ApplicationController
  skip_before_action :authenticate_user!, only: [:exchange_token]

  def exchange_token
    Rails.logger.info "Instagram token exchange request - params: #{params.inspect}"
    Rails.logger.info "Instagram token exchange request - headers: #{request.headers['Origin']}"
    
    code = params[:code]
    state = params[:state] 
    redirect_uri = params[:redirect_uri]

    if code.blank?
      return render json: { error: 'Authorization code is required' }, status: :bad_request
    end

    begin
      # Exchange authorization code for access token
      access_token_response = exchange_code_for_token(code, redirect_uri)
      
      # Exchange short-lived token for long-lived token
      long_lived_token_response = get_long_lived_token(access_token_response['access_token'])
      
      # Fetch account information (with error handling to not break connection flow)
      account_info = nil
      begin
        account_info = fetch_account_info(long_lived_token_response['access_token'])
        Rails.logger.info "Instagram account info fetched successfully"
      rescue => e
        Rails.logger.warn "Failed to fetch Instagram account info: #{e.message}"
        account_info = { error: 'Could not fetch account details' }
      end
      
      render json: {
        success: true,
        message: 'Instagram account connected successfully!',
        access_token: long_lived_token_response['access_token'],
        expires_in: long_lived_token_response['expires_in'],
        user_id: access_token_response['user_id'],
        account_info: account_info
      }
    rescue => e
      Rails.logger.error "Instagram OAuth error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        error: 'Failed to connect Instagram account', 
        details: e.message 
      }, status: :unprocessable_entity
    end
  end

  private

  def exchange_code_for_token(code, redirect_uri)
    uri = URI('https://api.instagram.com/oauth/access_token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data({
      'client_id' => ENV['INSTAGRAM_CLIENT_ID'],
      'client_secret' => ENV['INSTAGRAM_CLIENT_SECRET'],
      'grant_type' => 'authorization_code',
      'redirect_uri' => redirect_uri,
      'code' => code
    })

    response = http.request(request)
    
    if response.code.to_i >= 400
      error_data = JSON.parse(response.body) rescue {}
      raise "Instagram API error: #{error_data['error_message'] || response.body}"
    end

    JSON.parse(response.body)
  end

  def get_long_lived_token(short_lived_token)
    uri = URI('https://graph.instagram.com/access_token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    params = {
      'grant_type' => 'ig_exchange_token',
      'client_secret' => ENV['INSTAGRAM_CLIENT_SECRET'],
      'access_token' => short_lived_token
    }

    uri.query = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(uri)
    
    response = http.request(request)
    
    if response.code.to_i >= 400
      error_data = JSON.parse(response.body) rescue {}
      raise "Instagram Graph API error: #{error_data['error']['message'] || response.body}"
    end

    JSON.parse(response.body)
  end

  def fetch_account_info(access_token)
    uri = URI("https://graph.instagram.com/me")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    # With your approved permissions, we can fetch basic account info
    params = {
      'fields' => 'id,username,account_type,media_count',
      'access_token' => access_token
    }

    uri.query = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(uri)
    
    response = http.request(request)
    
    if response.code.to_i >= 400
      error_data = JSON.parse(response.body) rescue {}
      Rails.logger.warn "Instagram account info fetch failed: #{error_data}"
      return { error: 'Could not fetch account info' }
    end

    JSON.parse(response.body)
  end

  def create_or_update_instagram_account(instagram_user_id, access_token, expires_in, account_info)
    return nil if account_info.is_a?(Hash) && account_info['error']
    
    # For now, create a temporary user or find the first user
    # In production, this should be associated with the authenticated user
    user = User.first
    return nil unless user
    
    expires_at = expires_in ? expires_in.seconds.from_now : nil
    
    # Find or create Instagram account
    instagram_account = InstagramAccount.find_or_initialize_by(
      user: user,
      instagram_user_id: instagram_user_id.to_s
    )
    
    # Update account data
    instagram_account.assign_attributes({
      username: account_info['username'],
      account_type: account_info['account_type'] || 'PERSONAL',
      media_count: account_info['media_count'] || 0,
      access_token: access_token,
      token_expires_at: expires_at,
      connected_at: Time.current
    })
    
    if instagram_account.save
      Rails.logger.info "Instagram account saved: #{account_info['username']} (#{instagram_user_id})"
      instagram_account
    else
      Rails.logger.error "Failed to save Instagram account: #{instagram_account.errors.full_messages}"
      nil
    end
  rescue => e
    Rails.logger.error "Error saving Instagram account: #{e.message}"
    nil
  end
end