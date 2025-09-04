class InstagramTestController < ApplicationController
  skip_before_action :authenticate_user!, only: [:debug_config, :setup_guide, :validate_oauth_url]
  
  def debug_config
    render json: {
      instagram_client_id: ENV['INSTAGRAM_CLIENT_ID'],
      instagram_redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
      facebook_app_id: ENV['FACEBOOK_APP_ID'],
      auth_url: generate_auth_url_debug,
      rails_env: Rails.env,
      api_type: "Instagram Business OAuth (instagram.com)",
      required_facebook_products: [
        "Instagram Basic Display (required)",
        "Instagram API permissions (business scope)"
      ],
      facebook_console_url: "https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}/instagram-basic-display/basic-display/",
      setup_complete: check_setup_complete?,
      timestamp: Time.current
    }
  end
  
  def test_config
    render json: {
      instagram_client_id: ENV['INSTAGRAM_CLIENT_ID'],
      instagram_redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
      facebook_app_id: ENV['FACEBOOK_APP_ID'],
      auth_url: generate_auth_url,
      timestamp: Time.current
    }
  end

  def generate_auth_url
    client_id = ENV['INSTAGRAM_CLIENT_ID']
    redirect_uri = ENV['INSTAGRAM_REDIRECT_URI']
    scopes = ['user_profile', 'user_media']
    state = SecureRandom.hex(16)
    
    params = {
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scopes.join(','),
      response_type: 'code',
      state: state
    }
    
    query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    "https://api.instagram.com/oauth/authorize?#{query_string}"
  end
  
  def generate_auth_url_debug
    client_id = ENV['INSTAGRAM_CLIENT_ID']
    redirect_uri = ENV['INSTAGRAM_REDIRECT_URI']
    # Yesterday's successful Instagram business permissions
    scopes = [
      'instagram_business_basic',
      'instagram_business_manage_messages',
      'instagram_business_content_publish',
      'instagram_business_manage_comments',
      'instagram_business_manage_insights'
    ]
    state = 'debug123'
    logger_id = SecureRandom.uuid
    
    params = {
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: 'code',
      state: state,
      scope: scopes.join('-'), # Instagram business scopes use dash separator
      logger_id: logger_id,
      app_id: client_id,
      platform_app_id: client_id
    }
    
    params_json = params.to_json
    "https://www.instagram.com/consent/?flow=ig_biz_login_oauth&params_json=#{CGI.escape(params_json)}&source=oauth_permissions_page_www"
  end
  
  def check_setup_complete?
    ENV['INSTAGRAM_CLIENT_ID'].present? && 
    ENV['INSTAGRAM_CLIENT_SECRET'].present? && 
    ENV['INSTAGRAM_REDIRECT_URI'].present?
  end

  def test_token_exchange
    code = params[:code]
    
    if code.blank?
      return render json: { error: 'Code parameter is required' }, status: :bad_request
    end

    begin
      # Test the Instagram API token exchange
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
      
      render json: {
        status: response.status,
        success: response.success?,
        body: response.body,
        headers: response.headers.to_h,
        request_params: {
          client_id: ENV['INSTAGRAM_CLIENT_ID'],
          redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
          code: code
        }
      }
    rescue => e
      render json: {
        error: e.message,
        backtrace: e.backtrace.first(5)
      }, status: :internal_server_error
    end
  end
  
  def setup_guide
    render json: {
      title: "Instagram Basic Display API Setup Guide",
      facebook_app_id: ENV['FACEBOOK_APP_ID'],
      instagram_client_id: ENV['INSTAGRAM_CLIENT_ID'],
      current_status: check_setup_complete? ? "Configuration Complete" : "Setup Required",
      
      setup_steps: [
        {
          step: 1,
          title: "Go to Facebook Developer Console",
          url: "https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}",
          description: "Navigate to your Facebook app dashboard"
        },
        {
          step: 2,
          title: "Add Instagram Basic Display Product",
          action: "Click 'Add Product' in left sidebar",
          product: "Find 'Instagram Basic Display' and click 'Set Up'"
        },
        {
          step: 3,
          title: "Configure Basic Display Settings",
          url: "https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}/instagram-basic-display/basic-display/",
          settings: {
            "Instagram App ID": ENV['INSTAGRAM_CLIENT_ID'],
            "Instagram App Secret": ENV['INSTAGRAM_CLIENT_SECRET'],
            "Valid OAuth Redirect URIs": ENV['INSTAGRAM_REDIRECT_URI'],
            "Deauthorize Redirect URI": ENV['INSTAGRAM_REDIRECT_URI']
          }
        },
        {
          step: 4,
          title: "Add Test Users (Development)",
          action: "Click 'Add or Remove Instagram Users'",
          description: "Add your Instagram account as a test user for development"
        },
        {
          step: 5,
          title: "Test the Connection",
          test_url: generate_auth_url_debug,
          description: "Click the test URL to verify Instagram OAuth works"
        }
      ],
      
      common_errors: {
        "Invalid platform app": {
          cause: "Instagram Basic Display product not added to Facebook app",
          solution: "Complete steps 1-3 above"
        },
        "Invalid redirect URI": {
          cause: "OAuth redirect URI not configured correctly",
          solution: "Ensure #{ENV['INSTAGRAM_REDIRECT_URI']} is added to Valid OAuth Redirect URIs"
        },
        "Invalid client": {
          cause: "Instagram App ID/Secret mismatch",
          solution: "Verify Instagram App ID: #{ENV['INSTAGRAM_CLIENT_ID']}"
        }
      }
    }
  end
  
  def validate_oauth_url
    client_id = ENV['INSTAGRAM_CLIENT_ID']
    redirect_uri = ENV['INSTAGRAM_REDIRECT_URI']
    
    # Test if the OAuth URL is accessible
    auth_url = generate_auth_url_debug
    
    render json: {
      status: "Testing OAuth URL accessibility",
      auth_url: auth_url,
      client_id: client_id,
      redirect_uri: redirect_uri,
      
      validation_steps: [
        {
          step: "Check if Instagram Basic Display is added",
          status: "Manual verification required",
          instruction: "Go to https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}/settings/basic/ and verify 'Instagram Basic Display' appears in Products list"
        },
        {
          step: "Verify App Type",
          status: "Manual verification required", 
          instruction: "Ensure App Type is 'Consumer' (not Business) in Basic Settings"
        },
        {
          step: "Check OAuth Redirect URIs",
          expected_uri: redirect_uri,
          instruction: "Go to Instagram Basic Display → Basic Display → Client OAuth Settings"
        },
        {
          step: "Test URL manually",
          test_url: auth_url,
          instruction: "Click this URL to test Instagram OAuth"
        }
      ],
      
      debug_info: {
        rails_env: Rails.env,
        timestamp: Time.current,
        facebook_app_url: "https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}",
        instagram_basic_display_url: "https://developers.facebook.com/apps/#{ENV['FACEBOOK_APP_ID']}/instagram-basic-display/"
      }
    }
  end
end