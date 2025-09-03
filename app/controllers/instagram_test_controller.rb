class InstagramTestController < ApplicationController
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
end