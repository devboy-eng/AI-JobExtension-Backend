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