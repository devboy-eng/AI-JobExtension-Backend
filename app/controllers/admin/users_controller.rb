class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :update, :destroy, :suspend, :activate, :logs, :add_remark]
  
  required_permission 'users.view'
  
  def index
    users = User.includes(:instagram_accounts, :automations)
    
    # Apply filters
    users = users.where('email ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    users = users.where(plan: params[:plan]) if params[:plan].present?
    users = users.where(status: params[:status]) if params[:status].present?
    
    # Apply sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_order = params[:sort_order] || 'desc'
    users = users.order("#{sort_by} #{sort_order}")
    
    result = paginate(users)
    
    log_admin_activity('users_listed', "Viewed users list (page #{params[:page] || 1})")
    
    render json: {
      success: true,
      users: result[:data].map { |user| user_summary(user) },
      pagination: result[:pagination]
    }
  end
  
  def show
    log_admin_activity('user_viewed', "Viewed user details: #{@user.email}", @user)
    
    render json: {
      success: true,
      user: detailed_user_response(@user)
    }
  end
  
  def create
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.create')
    
    user = User.new(user_params)
    user.password = params[:password] || SecureRandom.hex(8)
    
    if user.save
      log_admin_activity('user_created', "Created user: #{user.email}", user)
      log_user_activity(user, 'account_created', "Account created by admin with #{user.plan} plan")
      
      # Send welcome email (implement as needed)
      # UserMailer.admin_created_account(user, params[:password]).deliver_later
      
      render json: {
        success: true,
        user: detailed_user_response(user),
        message: 'User created successfully'
      }
    else
      error_response('User creation failed', :unprocessable_entity, user.errors.full_messages)
    end
  end
  
  def update
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.edit')
    
    old_plan = @user.plan
    old_status = @user.status
    
    if @user.update(user_params)
      changes = track_changes(@user, old_plan, old_status)
      
      log_admin_activity('user_updated', "Updated user: #{@user.email} - #{changes}", @user)
      log_user_activity(@user, 'user_updated', changes) if changes.present?
      
      render json: {
        success: true,
        user: detailed_user_response(@user),
        message: 'User updated successfully'
      }
    else
      error_response('User update failed', :unprocessable_entity, @user.errors.full_messages)
    end
  end
  
  def destroy
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.delete')
    
    email = @user.email
    
    if @user.destroy
      log_admin_activity('user_deleted', "Deleted user: #{email}")
      success_response({}, 'User deleted successfully')
    else
      error_response('User deletion failed', :unprocessable_entity, @user.errors.full_messages)
    end
  end
  
  def suspend
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.suspend')
    
    reason = params[:reason] || 'Suspended by admin'
    
    if @user.update(status: 'suspended')
      log_admin_activity('user_suspended', "Suspended user: #{@user.email} - #{reason}", @user)
      log_user_activity(@user, 'account_suspended', "Account suspended by admin. Reason: #{reason}")
      
      # Send suspension notification
      # UserMailer.account_suspended(@user, reason).deliver_later
      
      success_response({ user: user_summary(@user) }, 'User suspended successfully')
    else
      error_response('Failed to suspend user', :unprocessable_entity, @user.errors.full_messages)
    end
  end
  
  def activate
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.activate')
    
    if @user.update(status: 'active')
      log_admin_activity('user_activated', "Activated user: #{@user.email}", @user)
      log_user_activity(@user, 'account_activated', 'Account activated by admin')
      
      # Send activation notification
      # UserMailer.account_activated(@user).deliver_later
      
      success_response({ user: user_summary(@user) }, 'User activated successfully')
    else
      error_response('Failed to activate user', :unprocessable_entity, @user.errors.full_messages)
    end
  end
  
  def change_plan
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.edit')
    
    old_plan = @user.plan
    new_plan = params[:plan]
    
    return error_response('Invalid plan') unless %w[free monthly_pro annual_pro custom].include?(new_plan)
    
    if @user.update(plan: new_plan)
      plan_names = {
        'free' => 'Free',
        'monthly_pro' => 'Monthly Pro (₹499/month)',
        'annual_pro' => 'Annual Pro (₹399/year)',
        'custom' => 'Custom'
      }
      
      change_details = "Plan changed from #{plan_names[old_plan]} to #{plan_names[new_plan]}"
      
      log_admin_activity('plan_changed', "Changed plan for #{@user.email}: #{change_details}", @user)
      log_user_activity(@user, 'plan_changed', change_details)
      
      success_response({ user: user_summary(@user) }, 'Plan updated successfully')
    else
      error_response('Failed to update plan', :unprocessable_entity, @user.errors.full_messages)
    end
  end
  
  def logs
    logs = UserLog.where(user: @user)
               .includes(:admin_user)
               .order(created_at: :desc)
    
    # Filter by date range if provided
    if params[:start_date].present? && params[:end_date].present?
      logs = logs.where(created_at: params[:start_date]..params[:end_date])
    end
    
    # Filter by action type
    logs = logs.where(action: params[:action]) if params[:action].present?
    
    result = paginate(logs, per_page: 50)
    
    log_admin_activity('user_logs_viewed', "Viewed activity logs for user: #{@user.email}", @user)
    
    render json: {
      success: true,
      logs: result[:data].map do |log|
        {
          id: log.id,
          action: log.action,
          details: log.details,
          admin_user: log.admin_name,
          created_at: log.formatted_created_at,
          category: log.category,
          is_admin_action: log.is_admin_action?
        }
      end,
      pagination: result[:pagination]
    }
  end
  
  def add_remark
    remark = params[:remark]
    return error_response('Remark is required') if remark.blank?
    
    log_user_activity(@user, 'admin_remark', remark)
    log_admin_activity('remark_added', "Added remark for user #{@user.email}: #{remark.truncate(100)}", @user)
    
    success_response({}, 'Remark added successfully')
  end
  
  def export
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('users.export')
    
    users = User.includes(:instagram_accounts, :automations)
    
    # Apply same filters as index
    users = users.where('email ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    users = users.where(plan: params[:plan]) if params[:plan].present?
    users = users.where(status: params[:status]) if params[:status].present?
    
    export_data = users.map do |user|
      {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        plan: user.plan,
        status: user.status,
        created_at: user.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        instagram_accounts: user.instagram_accounts.count,
        automations: user.automations.count,
        dm_usage: "#{user.current_month_dm_count}/#{user.dm_limit}",
        contact_usage: "#{user.current_month_contact_count}/#{user.contact_limit}"
      }
    end
    
    log_admin_activity('users_exported', "Exported #{export_data.count} users")
    
    render json: {
      success: true,
      data: export_data,
      count: export_data.count,
      exported_at: Time.current.strftime('%Y-%m-%d %H:%M:%S')
    }
  end
  
  def stats
    render json: {
      success: true,
      stats: {
        total_users: User.count,
        active_users: User.where(status: 'active').count,
        suspended_users: User.where(status: 'suspended').count,
        plan_distribution: User.group(:plan).count,
        new_users_this_month: User.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count,
        top_referrers: User.joins(:referrals).group(:referral_code).count.sort_by(&:last).reverse.first(10)
      }
    }
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end
  
  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :plan, :status)
  end
  
  def user_summary(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: "#{user.first_name} #{user.last_name}".strip,
      plan: user.plan,
      status: user.status,
      created_at: user.created_at.strftime('%Y-%m-%d'),
      last_sign_in_at: user.last_sign_in_at&.strftime('%Y-%m-%d %H:%M'),
      instagram_accounts_count: user.instagram_accounts.count,
      automations_count: user.automations.count,
      dm_usage: {
        current: user.current_month_dm_count,
        limit: user.dm_limit,
        percentage: user.dm_limit > 0 ? (user.current_month_dm_count.to_f / user.dm_limit * 100).round(2) : 0
      },
      contact_usage: {
        current: user.current_month_contact_count,
        limit: user.contact_limit,
        percentage: user.contact_limit > 0 ? (user.current_month_contact_count.to_f / user.contact_limit * 100).round(2) : 0
      }
    }
  end
  
  def detailed_user_response(user)
    user_summary(user).merge(
      referral_code: user.referral_code,
      referral_link: user.referral_link,
      total_referrals: user.total_referrals,
      referral_earnings: user.referral_earnings,
      instagram_accounts: user.instagram_accounts.map do |account|
        {
          id: account.id,
          username: account.username,
          connected_at: account.connected_at&.strftime('%Y-%m-%d %H:%M'),
          status: account.token_expires_at > Time.current ? 'active' : 'expired'
        }
      end,
      recent_automations: user.automations.limit(5).map do |automation|
        {
          id: automation.id,
          name: automation.name,
          status: automation.status,
          created_at: automation.created_at.strftime('%Y-%m-%d')
        }
      end,
      usage_summary: {
        dms_sent_this_month: user.current_month_dm_count,
        contacts_added_this_month: user.current_month_contact_count,
        automations_created: user.automations.count,
        last_activity: user.updated_at.strftime('%Y-%m-%d %H:%M')
      }
    )
  end
  
  def track_changes(user, old_plan, old_status)
    changes = []
    changes << "Plan: #{old_plan} → #{user.plan}" if old_plan != user.plan
    changes << "Status: #{old_status} → #{user.status}" if old_status != user.status
    changes.join(', ')
  end
end