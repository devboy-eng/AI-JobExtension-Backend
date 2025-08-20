class AuthController < ApplicationController
  def create
    user = User.new(user_params)
    
    if user.save
      token = generate_token(user)
      render json: {
        user: user_response(user),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def login
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      token = generate_token(user)
      render json: {
        user: user_response(user),
        token: token
      }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
  
  def logout
    render json: { message: 'Logged out successfully' }
  end
  
  def me
    render json: { user: user_response(current_user) }
  end
  
  def profile
    render json: {
      id: current_user.id,
      email: current_user.email,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      plan: current_user.plan,
      referral_code: current_user.referral_code,
      referral_link: current_user.referral_link,
      total_referrals: current_user.total_referrals,
      referral_earnings: current_user.referral_earnings
    }
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :password, :first_name, :last_name)
  end
  
  def user_response(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      plan: user.plan,
      dm_usage: "#{user.current_month_dm_count}/#{user.dm_limit}",
      contact_usage: "#{user.current_month_contact_count}/#{user.contact_limit}"
    }
  end
end