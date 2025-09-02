class Admin::DashboardController < Admin::BaseController
  required_permission 'dashboard.view'
  
  def index
    log_admin_activity('dashboard_accessed', 'Admin accessed dashboard')
    
    render json: {
      success: true,
      data: {
        overview: overview_stats,
        users: user_stats,
        revenue: revenue_stats,
        automation: automation_stats,
        recent_activities: recent_activities,
        system_health: system_health
      }
    }
  end
  
  def user_growth
    days = params[:days]&.to_i || 30
    
    user_growth_data = User.where(created_at: days.days.ago..Time.current)
                          .group_by_day(:created_at)
                          .count
    
    render json: {
      success: true,
      data: {
        period: "#{days} days",
        growth_data: user_growth_data,
        total_new_users: user_growth_data.values.sum,
        average_daily: (user_growth_data.values.sum.to_f / days).round(2)
      }
    }
  end
  
  def revenue_analytics
    period = params[:period] || 'month'
    
    case period
    when 'week'
      start_date = 1.week.ago
      group_by = :day
    when 'month'
      start_date = 1.month.ago
      group_by = :day
    when 'year'
      start_date = 1.year.ago
      group_by = :month
    else
      start_date = 1.month.ago
      group_by = :day
    end
    
    # This would need to be connected to your actual payment system
    revenue_data = {
      # Placeholder - replace with actual payment data
      total_revenue: calculate_total_revenue(start_date),
      subscription_revenue: calculate_subscription_revenue(start_date),
      refunds: calculate_refunds(start_date),
      growth_rate: calculate_revenue_growth_rate(start_date, period)
    }
    
    render json: {
      success: true,
      data: revenue_data
    }
  end
  
  def system_metrics
    render json: {
      success: true,
      data: {
        database: {
          users_count: User.count,
          automations_count: Automation.count,
          contacts_count: Contact.count,
          instagram_accounts_count: InstagramAccount.count
        },
        performance: {
          average_response_time: calculate_average_response_time,
          error_rate: calculate_error_rate,
          uptime: calculate_uptime
        },
        storage: {
          database_size: calculate_database_size,
          log_files_size: calculate_log_files_size,
          total_storage: calculate_total_storage
        }
      }
    }
  end
  
  private
  
  def overview_stats
    {
      total_users: User.count,
      active_users: User.where('last_sign_in_at > ?', 30.days.ago).count,
      pro_users: User.where(plan: ['pro', 'monthly_pro', 'annual_pro']).count,
      total_automations: Automation.count,
      active_automations: Automation.where(status: 'active').count,
      total_revenue: calculate_total_revenue(1.month.ago),
      growth_rate: calculate_user_growth_rate
    }
  end
  
  def user_stats
    {
      new_users_today: User.where(created_at: Date.current.all_day).count,
      new_users_week: User.where(created_at: 1.week.ago..Time.current).count,
      new_users_month: User.where(created_at: 1.month.ago..Time.current).count,
      plan_distribution: User.group(:plan).count,
      top_referrers: User.joins(:referrals).group(:referral_code).count.sort_by(&:last).reverse.first(5)
    }
  end
  
  def revenue_stats
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    last_month = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    
    {
      current_month: calculate_total_revenue(Date.current.beginning_of_month),
      last_month: calculate_total_revenue(1.month.ago.beginning_of_month),
      total_lifetime: calculate_total_revenue(User.minimum(:created_at) || 1.year.ago),
      average_revenue_per_user: calculate_arpu,
      monthly_growth: calculate_monthly_revenue_growth
    }
  end
  
  def automation_stats
    {
      total_automations: Automation.count,
      active_automations: Automation.where(status: 'active').count,
      paused_automations: Automation.where(status: 'paused').count,
      total_dms_sent: UsageMetric.where(metric_type: 'dm_sent').sum(:count),
      dms_this_month: UsageMetric.where(
        metric_type: 'dm_sent',
        created_at: Date.current.beginning_of_month..Date.current.end_of_month
      ).sum(:count),
      top_keywords: Automation.group(:trigger_keyword).count.sort_by(&:last).reverse.first(10)
    }
  end
  
  def recent_activities
    admin_activities = AdminLog.recent.limit(10).includes(:admin_user)
    user_activities = UserLog.recent.limit(10).includes(:user, :admin_user)
    
    all_activities = (admin_activities + user_activities)
                      .sort_by(&:created_at)
                      .reverse
                      .first(15)
    
    all_activities.map do |activity|
      if activity.is_a?(AdminLog)
        {
          type: 'admin',
          action: activity.action,
          details: activity.details,
          admin_name: activity.admin_name,
          created_at: activity.formatted_created_at,
          severity: activity.severity
        }
      else
        {
          type: 'user',
          action: activity.action,
          details: activity.details,
          user_email: activity.user.email,
          admin_name: activity.admin_name,
          created_at: activity.formatted_created_at,
          category: activity.category
        }
      end
    end
  end
  
  def system_health
    {
      status: 'healthy', # This would be determined by actual health checks
      uptime: calculate_uptime,
      cpu_usage: rand(10..30), # Placeholder - integrate with actual monitoring
      memory_usage: rand(40..70), # Placeholder
      disk_usage: rand(20..50), # Placeholder
      active_connections: rand(50..200), # Placeholder
      last_backup: calculate_last_backup_time,
      pending_jobs: calculate_pending_jobs
    }
  end
  
  # Placeholder calculation methods - replace with actual implementations
  
  def calculate_total_revenue(start_date)
    # This would integrate with your payment system
    # For now, calculate based on pro users
    pro_users = User.where(plan: ['pro', 'monthly_pro', 'annual_pro'])
                   .where('created_at >= ?', start_date)
    
    # Rough calculation - replace with actual payment data
    monthly_pro = pro_users.where(plan: 'monthly_pro').count * 499
    annual_pro = pro_users.where(plan: 'annual_pro').count * 399
    
    monthly_pro + annual_pro
  end
  
  def calculate_subscription_revenue(start_date)
    calculate_total_revenue(start_date) * 0.95 # Assuming 5% refunds
  end
  
  def calculate_refunds(start_date)
    calculate_total_revenue(start_date) * 0.05 # 5% refund rate
  end
  
  def calculate_revenue_growth_rate(start_date, period)
    current_revenue = calculate_total_revenue(start_date)
    previous_revenue = case period
    when 'week'
      calculate_total_revenue(2.weeks.ago)
    when 'month'
      calculate_total_revenue(2.months.ago)
    when 'year'
      calculate_total_revenue(2.years.ago)
    else
      calculate_total_revenue(2.months.ago)
    end
    
    return 0 if previous_revenue.zero?
    ((current_revenue - previous_revenue) / previous_revenue.to_f * 100).round(2)
  end
  
  def calculate_user_growth_rate
    current_month_users = User.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    last_month_users = User.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count
    
    return 0 if last_month_users.zero?
    ((current_month_users - last_month_users) / last_month_users.to_f * 100).round(2)
  end
  
  def calculate_arpu
    total_revenue = calculate_total_revenue(1.year.ago)
    total_users = User.count
    return 0 if total_users.zero?
    (total_revenue / total_users.to_f).round(2)
  end
  
  def calculate_monthly_revenue_growth
    calculate_revenue_growth_rate(1.month.ago, 'month')
  end
  
  def calculate_average_response_time
    # Placeholder - integrate with APM tool
    rand(50..200)
  end
  
  def calculate_error_rate
    # Placeholder - integrate with error tracking
    rand(0.1..2.5)
  end
  
  def calculate_uptime
    # Placeholder - integrate with uptime monitoring
    rand(99.5..100.0).round(2)
  end
  
  def calculate_database_size
    # Placeholder - get actual database size
    "#{rand(100..500)}MB"
  end
  
  def calculate_log_files_size
    # Placeholder - get actual log size
    "#{rand(50..200)}MB"
  end
  
  def calculate_total_storage
    # Placeholder - get actual storage usage
    "#{rand(500..2000)}MB"
  end
  
  def calculate_last_backup_time
    # Placeholder - get actual backup time
    rand(1..24).hours.ago
  end
  
  def calculate_pending_jobs
    # Placeholder - get actual job count
    begin
      Sidekiq::Queue.new.size
    rescue
      0
    end
  end
end