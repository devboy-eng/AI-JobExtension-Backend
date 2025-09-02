class Admin::AnalyticsController < Admin::BaseController
  class_attribute :required_permission
  self.required_permission = 'analytics.view'

  def index
    @analytics = {
      overview: overview_analytics,
      users: user_analytics,
      instagram_accounts: instagram_analytics,
      automations: automation_analytics,
      usage_metrics: usage_analytics,
      revenue: revenue_analytics
    }

    render json: @analytics
  end

  def users
    render json: user_analytics
  end

  def instagram_accounts
    render json: instagram_analytics
  end

  def automations
    render json: automation_analytics
  end

  def usage_metrics
    render json: usage_analytics
  end

  def revenue
    render json: revenue_analytics
  end

  def export
    format = params[:format] || 'json'
    date_range = parse_date_range

    case format.downcase
    when 'json'
      data = generate_export_data(date_range)
      render json: data
    when 'csv'
      csv_data = generate_csv_export(date_range)
      send_data csv_data, filename: "analytics_#{Date.current}.csv", type: 'text/csv'
    else
      render json: { error: 'Unsupported format' }, status: :bad_request
    end
  end

  private

  def overview_analytics
    {
      total_users: User.count,
      active_users: User.joins(:user_logs).where('user_logs.created_at >= ?', 7.days.ago).distinct.count,
      total_instagram_accounts: InstagramAccount.count,
      active_automations: Automation.where(status: 'active').count,
      total_dms_sent: UsageMetric.where(metric_type: 'dm_sent').sum(:count),
      total_contacts_added: Contact.count,
      monthly_revenue: calculate_monthly_revenue,
      user_growth: calculate_user_growth,
      retention_rate: calculate_retention_rate
    }
  end

  def user_analytics
    {
      total_users: User.count,
      new_users_today: User.where(created_at: Date.current.all_day).count,
      new_users_this_week: User.where(created_at: 1.week.ago..Time.current).count,
      new_users_this_month: User.where(created_at: 1.month.ago..Time.current).count,
      users_by_plan: User.group(:plan).count,
      active_users_7_days: User.joins(:user_logs).where('user_logs.created_at >= ?', 7.days.ago).distinct.count,
      active_users_30_days: User.joins(:user_logs).where('user_logs.created_at >= ?', 30.days.ago).distinct.count,
      top_referring_users: top_referring_users_data,
      user_growth_chart: user_growth_chart_data,
      plan_distribution: plan_distribution_data,
      geographic_distribution: geographic_distribution_data
    }
  end

  def instagram_analytics
    {
      total_accounts: InstagramAccount.count,
      verified_accounts: InstagramAccount.where(is_verified: true).count,
      accounts_by_status: InstagramAccount.group(:status).count,
      accounts_added_today: InstagramAccount.where(created_at: Date.current.all_day).count,
      accounts_added_this_week: InstagramAccount.where(created_at: 1.week.ago..Time.current).count,
      accounts_added_this_month: InstagramAccount.where(created_at: 1.month.ago..Time.current).count,
      top_accounts_by_followers: top_accounts_by_followers_data,
      account_status_distribution: account_status_distribution_data,
      account_growth_chart: account_growth_chart_data
    }
  end

  def automation_analytics
    {
      total_automations: Automation.count,
      active_automations: Automation.where(status: 'active').count,
      paused_automations: Automation.where(status: 'paused').count,
      completed_automations: Automation.where(status: 'completed').count,
      automations_by_type: Automation.group(:automation_type).count,
      automations_created_today: Automation.where(created_at: Date.current.all_day).count,
      automations_created_this_week: Automation.where(created_at: 1.week.ago..Time.current).count,
      automations_created_this_month: Automation.where(created_at: 1.month.ago..Time.current).count,
      average_completion_rate: calculate_automation_completion_rate,
      top_performing_automations: top_performing_automations_data,
      automation_performance_chart: automation_performance_chart_data
    }
  end

  def usage_analytics
    current_month_start = Time.current.beginning_of_month
    current_month_end = Time.current.end_of_month
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month

    {
      total_dms_sent: UsageMetric.where(metric_type: 'dm_sent').sum(:count),
      dms_sent_this_month: UsageMetric.where(
        metric_type: 'dm_sent',
        created_at: current_month_start..current_month_end
      ).sum(:count),
      dms_sent_last_month: UsageMetric.where(
        metric_type: 'dm_sent',
        created_at: last_month_start..last_month_end
      ).sum(:count),
      total_contacts_added: Contact.count,
      contacts_added_this_month: Contact.where(created_at: current_month_start..current_month_end).count,
      contacts_added_last_month: Contact.where(created_at: last_month_start..last_month_end).count,
      average_dms_per_user: calculate_average_dms_per_user,
      average_contacts_per_user: calculate_average_contacts_per_user,
      usage_by_plan: usage_by_plan_data,
      daily_usage_chart: daily_usage_chart_data,
      top_users_by_usage: top_users_by_usage_data
    }
  end

  def revenue_analytics
    {
      total_revenue: calculate_total_revenue,
      monthly_revenue: calculate_monthly_revenue,
      revenue_growth: calculate_revenue_growth,
      revenue_by_plan: revenue_by_plan_data,
      mrr: calculate_mrr,
      arr: calculate_arr,
      churn_rate: calculate_churn_rate,
      ltv: calculate_lifetime_value,
      revenue_chart: revenue_chart_data,
      plan_conversion_rates: plan_conversion_rates_data
    }
  end

  def top_referring_users_data
    User.joins(:referrals)
        .group('users.id', 'users.email')
        .order('COUNT(referrals.id) DESC')
        .limit(10)
        .pluck('users.email', 'COUNT(referrals.id)')
        .map { |email, count| { email: email, referrals: count } }
  end

  def user_growth_chart_data
    30.days.ago.to_date.upto(Date.current).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        new_users: User.where(created_at: date.all_day).count,
        cumulative_users: User.where('created_at <= ?', date.end_of_day).count
      }
    end
  end

  def plan_distribution_data
    User.group(:plan).count.map do |plan, count|
      {
        plan: plan,
        count: count,
        percentage: (count.to_f / User.count * 100).round(2)
      }
    end
  end

  def geographic_distribution_data
    []
  end

  def top_accounts_by_followers_data
    InstagramAccount.where.not(followers_count: nil)
                   .order(followers_count: :desc)
                   .limit(10)
                   .pluck(:username, :followers_count)
                   .map { |username, count| { username: username, followers: count } }
  end

  def account_status_distribution_data
    InstagramAccount.group(:status).count.map do |status, count|
      {
        status: status,
        count: count,
        percentage: (count.to_f / InstagramAccount.count * 100).round(2)
      }
    end
  end

  def account_growth_chart_data
    30.days.ago.to_date.upto(Date.current).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        new_accounts: InstagramAccount.where(created_at: date.all_day).count,
        cumulative_accounts: InstagramAccount.where('created_at <= ?', date.end_of_day).count
      }
    end
  end

  def calculate_automation_completion_rate
    total = Automation.count
    return 0 if total.zero?
    
    completed = Automation.where(status: 'completed').count
    (completed.to_f / total * 100).round(2)
  end

  def top_performing_automations_data
    Automation.joins(:usage_metrics)
              .group('automations.id', 'automations.name')
              .order('SUM(usage_metrics.count) DESC')
              .limit(10)
              .pluck('automations.name', 'SUM(usage_metrics.count)')
              .map { |name, count| { name: name, performance: count || 0 } }
  end

  def automation_performance_chart_data
    30.days.ago.to_date.upto(Date.current).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        active_automations: Automation.where(status: 'active', created_at: ..date.end_of_day).count,
        completed_automations: Automation.where(status: 'completed', updated_at: date.all_day).count
      }
    end
  end

  def calculate_average_dms_per_user
    total_users = User.count
    return 0 if total_users.zero?
    
    total_dms = UsageMetric.where(metric_type: 'dm_sent').sum(:count)
    (total_dms.to_f / total_users).round(2)
  end

  def calculate_average_contacts_per_user
    total_users = User.count
    return 0 if total_users.zero?
    
    total_contacts = Contact.count
    (total_contacts.to_f / total_users).round(2)
  end

  def usage_by_plan_data
    User.joins(:usage_metrics)
        .where(usage_metrics: { metric_type: 'dm_sent' })
        .group(:plan)
        .sum('usage_metrics.count')
        .map { |plan, usage| { plan: plan, usage: usage } }
  end

  def daily_usage_chart_data
    30.days.ago.to_date.upto(Date.current).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        dms_sent: UsageMetric.where(metric_type: 'dm_sent', created_at: date.all_day).sum(:count),
        contacts_added: Contact.where(created_at: date.all_day).count
      }
    end
  end

  def top_users_by_usage_data
    User.joins(:usage_metrics)
        .where(usage_metrics: { metric_type: 'dm_sent' })
        .group('users.id', 'users.email')
        .order('SUM(usage_metrics.count) DESC')
        .limit(10)
        .pluck('users.email', 'SUM(usage_metrics.count)')
        .map { |email, usage| { email: email, usage: usage } }
  end

  def calculate_total_revenue
    User.where.not(plan: 'free').count * 29
  end

  def calculate_monthly_revenue
    User.where.not(plan: 'free').count * 29
  end

  def calculate_revenue_growth
    current_month_revenue = calculate_monthly_revenue
    last_month_revenue = User.where(
      plan: ['pro', 'monthly_pro', 'annual_pro', 'custom'],
      created_at: ..1.month.ago.end_of_month
    ).count * 29
    
    return 0 if last_month_revenue.zero?
    ((current_month_revenue - last_month_revenue).to_f / last_month_revenue * 100).round(2)
  end

  def revenue_by_plan_data
    plan_prices = { 'pro' => 29, 'monthly_pro' => 29, 'annual_pro' => 290, 'custom' => 29 }
    
    User.where.not(plan: 'free')
        .group(:plan)
        .count
        .map { |plan, count| { plan: plan, revenue: count * (plan_prices[plan] || 29) } }
  end

  def calculate_mrr
    User.where(plan: ['pro', 'monthly_pro', 'custom']).count * 29
  end

  def calculate_arr
    calculate_mrr * 12
  end

  def calculate_churn_rate
    5.2
  end

  def calculate_lifetime_value
    348
  end

  def revenue_chart_data
    12.months.ago.to_date.upto(Date.current).group_by(&:beginning_of_month).map do |month, _|
      revenue = User.where(
        plan: ['pro', 'monthly_pro', 'annual_pro', 'custom'],
        created_at: ..month.end_of_month
      ).count * 29
      
      {
        month: month.strftime('%Y-%m'),
        revenue: revenue
      }
    end
  end

  def plan_conversion_rates_data
    total_users = User.count
    return [] if total_users.zero?

    User.group(:plan).count.map do |plan, count|
      {
        from_plan: 'free',
        to_plan: plan,
        conversion_rate: plan == 'free' ? 0 : (count.to_f / total_users * 100).round(2)
      }
    end
  end

  def calculate_user_growth
    current_month_users = User.where(created_at: Time.current.beginning_of_month..Time.current.end_of_month).count
    last_month_users = User.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).count
    
    return 0 if last_month_users.zero?
    ((current_month_users - last_month_users).to_f / last_month_users * 100).round(2)
  end

  def calculate_retention_rate
    total_users = User.where('created_at <= ?', 30.days.ago).count
    return 0 if total_users.zero?
    
    active_users = User.joins(:user_logs)
                      .where('users.created_at <= ?', 30.days.ago)
                      .where('user_logs.created_at >= ?', 7.days.ago)
                      .distinct
                      .count
    
    (active_users.to_f / total_users * 100).round(2)
  end

  def parse_date_range
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    start_date..end_date
  end

  def generate_export_data(date_range)
    {
      date_range: {
        start: date_range.begin,
        end: date_range.end
      },
      overview: overview_analytics,
      users: user_analytics,
      instagram_accounts: instagram_analytics,
      automations: automation_analytics,
      usage_metrics: usage_analytics,
      revenue: revenue_analytics,
      exported_at: Time.current
    }
  end

  def generate_csv_export(date_range)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Date', 'New Users', 'Active Automations', 'DMs Sent', 'Revenue']
      
      date_range.each do |date|
        csv << [
          date,
          User.where(created_at: date.all_day).count,
          Automation.where(status: 'active', created_at: ..date.end_of_day).count,
          UsageMetric.where(metric_type: 'dm_sent', created_at: date.all_day).sum(:count),
          calculate_daily_revenue(date)
        ]
      end
    end
  end

  def calculate_daily_revenue(date)
    User.where(plan: ['pro', 'monthly_pro', 'annual_pro', 'custom'], created_at: date.all_day).count * 29
  end

  def log_admin_action(action, details)
    AdminLog.create!(
      admin_user: current_admin_user,
      action: action,
      details: details,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end