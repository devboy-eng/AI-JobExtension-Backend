class AdminController < ActionController::Base
  include ActionController::Cookies
  skip_before_action :verify_authenticity_token, raise: false
  before_action :authenticate_admin!, except: [:login, :authenticate]
  
  # Simple hardcoded admin credentials
  ADMIN_USERNAME = 'admin'
  ADMIN_PASSWORD = 'admin123'
  ADMIN_TOKEN = 'admin_token_job_extension_2024'
  
  def login
    if cookies[:admin_token] == ADMIN_TOKEN
      redirect_to simple_admin_dashboard_path
    else
      render html: login_html.html_safe
    end
  end
  
  def authenticate
    username = params[:username]
    password = params[:password]
    
    if username == ADMIN_USERNAME && password == ADMIN_PASSWORD
      cookies[:admin_token] = { value: ADMIN_TOKEN, expires: 24.hours.from_now }
      redirect_to simple_admin_dashboard_path
    else
      render html: login_html('Invalid credentials').html_safe
    end
  end
  
  def logout
    cookies.delete(:admin_token)
    redirect_to simple_admin_login_path
  end
  
  def dashboard
    @users = User.includes(:customizations, :resume_versions).order(:created_at).limit(50)
    render html: dashboard_html.html_safe
  end
  
  def users
    @users = User.includes(:customizations, :resume_versions).order(:created_at)
    render html: users_html.html_safe
  end
  
  def user_coins
    @user = User.find(params[:id])
    render html: user_coins_html.html_safe
  end
  
  def add_coins
    @user = User.find(params[:id])
    coins = params[:coins].to_i
    
    if coins > 0
      @user.add_coins(coins)
      redirect_to simple_admin_users_path
    else
      redirect_to simple_admin_users_path
    end
  end
  
  private
  
  def authenticate_admin!
    unless cookies[:admin_token] == ADMIN_TOKEN
      redirect_to simple_admin_login_path
    end
  end
  
  def login_html(error = nil)
    %{
    <!DOCTYPE html>
    <html>
    <head>
      <title>Job Extension Admin</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 400px; margin: 100px auto; padding: 20px; }
        .form-group { margin: 15px 0; }
        label { display: block; margin-bottom: 5px; }
        input { width: 100%; padding: 8px; margin-bottom: 10px; }
        button { background: #007cba; color: white; padding: 10px 20px; border: none; cursor: pointer; }
        .error { color: red; margin: 10px 0; }
      </style>
    </head>
    <body>
      <h2>Job Extension Admin Login</h2>
      #{error ? %{<div class="error">#{error}</div>} : ''}
      <form method="post" action="#{simple_admin_authenticate_path}">
        <div class="form-group">
          <label>Username:</label>
          <input type="text" name="username" required>
        </div>
        <div class="form-group">
          <label>Password:</label>
          <input type="password" name="password" required>
        </div>
        <button type="submit">Login</button>
      </form>
    </body>
    </html>
    }
  end
  
  def dashboard_html
    %{
    <!DOCTYPE html>
    <html>
    <head>
      <title>Job Extension Admin Dashboard</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .nav { margin: 20px 0; }
        .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        th { background: #f5f5f5; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Job Extension Admin Dashboard</h1>
        <a href="#{simple_admin_logout_path}">Logout</a>
      </div>
      
      <div class="nav">
        <a href="#{simple_admin_dashboard_path}">Dashboard</a>
        <a href="#{simple_admin_users_path}">All Users</a>
      </div>
      
      <h3>Recent Users (#{@users.count})</h3>
      <table>
        <tr>
          <th>Email</th>
          <th>Plan</th>
          <th>Coins</th>
          <th>Customizations</th>
          <th>Joined</th>
          <th>Actions</th>
        </tr>
        #{@users.map { |user| %{
        <tr>
          <td>#{user.email}</td>
          <td>#{user.plan}</td>
          <td>#{user.coin_balance}</td>
          <td>#{user.customizations.count}</td>
          <td>#{user.created_at.strftime('%Y-%m-%d')}</td>
          <td><a href="#{simple_admin_user_coins_path(user)}">Manage Coins</a></td>
        </tr>
        } }.join}
      </table>
    </body>
    </html>
    }
  end
  
  def users_html
    %{
    <!DOCTYPE html>
    <html>
    <head>
      <title>Job Extension Admin - Users</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .nav { margin: 20px 0; }
        .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        th { background: #f5f5f5; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>All Users</h1>
        <a href="#{simple_admin_logout_path}">Logout</a>
      </div>
      
      <div class="nav">
        <a href="#{simple_admin_dashboard_path}">Dashboard</a>
        <a href="#{simple_admin_users_path}">All Users</a>
      </div>
      
      <table>
        <tr>
          <th>Email</th>
          <th>Plan</th>
          <th>Coins</th>
          <th>Customizations</th>
          <th>Resume Versions</th>
          <th>Joined</th>
          <th>Actions</th>
        </tr>
        #{@users.map { |user| %{
        <tr>
          <td>#{user.email}</td>
          <td>#{user.plan}</td>
          <td>#{user.coin_balance}</td>
          <td>#{user.customizations.count}</td>
          <td>#{user.resume_versions.count}</td>
          <td>#{user.created_at.strftime('%Y-%m-%d')}</td>
          <td><a href="#{simple_admin_user_coins_path(user)}">Manage Coins</a></td>
        </tr>
        } }.join}
      </table>
    </body>
    </html>
    }
  end
  
  def user_coins_html
    %{
    <!DOCTYPE html>
    <html>
    <head>
      <title>Manage Coins - #{@user.email}</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; max-width: 600px; }
        .form-group { margin: 15px 0; }
        label { display: block; margin-bottom: 5px; }
        input { padding: 8px; margin-bottom: 10px; }
        button { background: #007cba; color: white; padding: 10px 20px; border: none; cursor: pointer; margin-right: 10px; }
        .back-btn { background: #666; }
      </style>
    </head>
    <body>
      <h1>Manage Coins for #{@user.email}</h1>
      
      <p><strong>Current Balance:</strong> #{@user.coin_balance} coins</p>
      <p><strong>Plan:</strong> #{@user.plan}</p>
      <p><strong>Joined:</strong> #{@user.created_at.strftime('%Y-%m-%d')}</p>
      
      <form method="post" action="#{simple_admin_add_coins_path(@user)}">
        <div class="form-group">
          <label>Add Coins:</label>
          <input type="number" name="coins" min="1" max="1000" required>
        </div>
        <button type="submit">Add Coins</button>
        <a href="#{simple_admin_users_path}" class="back-btn" style="text-decoration: none; color: white; padding: 10px 20px; background: #666;">Back to Users</a>
      </form>
    </body>
    </html>
    }
  end
end