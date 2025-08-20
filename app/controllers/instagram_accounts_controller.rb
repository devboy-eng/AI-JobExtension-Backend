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
    # Instagram OAuth callback handling
    code = params[:code]
    
    # Exchange code for access token
    response = Faraday.post("https://api.instagram.com/oauth/access_token") do |req|
      req.body = {
        client_id: ENV['INSTAGRAM_CLIENT_ID'],
        client_secret: ENV['INSTAGRAM_CLIENT_SECRET'],
        grant_type: 'authorization_code',
        redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'],
        code: code
      }
    end
    
    if response.success?
      data = JSON.parse(response.body)
      
      account = current_user.instagram_accounts.build(
        instagram_user_id: data['user_id'].to_s,
        username: data['username'] || 'Unknown',
        access_token: data['access_token'],
        token_expires_at: Time.current + 60.days
      )
      
      if account.save
        render json: account, status: :created
      else
        render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Failed to connect Instagram account' }, status: :unprocessable_entity
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