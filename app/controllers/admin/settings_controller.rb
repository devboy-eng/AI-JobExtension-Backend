class Admin::SettingsController < Admin::BaseController
  class_attribute :required_permission
  self.required_permission = 'settings.manage'

  def index
    @settings = {
      system: system_settings,
      security: security_settings,
      email: email_settings,
      integration: integration_settings,
      rate_limits: rate_limit_settings,
      plans: plan_settings
    }

    render json: @settings
  end

  def update
    setting_type = params[:type]
    setting_key = params[:key]
    setting_value = params[:value]

    case setting_type
    when 'system'
      update_system_setting(setting_key, setting_value)
    when 'security'
      update_security_setting(setting_key, setting_value)
    when 'email'
      update_email_setting(setting_key, setting_value)
    when 'integration'
      update_integration_setting(setting_key, setting_value)
    when 'rate_limits'
      update_rate_limit_setting(setting_key, setting_value)
    when 'plans'
      update_plan_setting(setting_key, setting_value)
    else
      return render json: { error: 'Invalid setting type' }, status: :bad_request
    end

    log_admin_action('setting_updated', {
      type: setting_type,
      key: setting_key,
      value: setting_value
    })

    render json: { message: 'Setting updated successfully' }
  end

  def bulk_update
    settings = params[:settings] || []
    updated_count = 0

    settings.each do |setting|
      type = setting[:type]
      key = setting[:key]
      value = setting[:value]

      case type
      when 'system'
        update_system_setting(key, value)
      when 'security'
        update_security_setting(key, value)
      when 'email'
        update_email_setting(key, value)
      when 'integration'
        update_integration_setting(key, value)
      when 'rate_limits'
        update_rate_limit_setting(key, value)
      when 'plans'
        update_plan_setting(key, value)
      end

      updated_count += 1
    end

    log_admin_action('bulk_settings_update', {
      count: updated_count,
      settings: settings.map { |s| "#{s[:type]}.#{s[:key]}" }
    })

    render json: { 
      message: "#{updated_count} settings updated successfully",
      updated_count: updated_count
    }
  end

  def reset_to_defaults
    setting_type = params[:type]

    case setting_type
    when 'system'
      reset_system_settings
    when 'security'
      reset_security_settings
    when 'email'
      reset_email_settings
    when 'integration'
      reset_integration_settings
    when 'rate_limits'
      reset_rate_limit_settings
    when 'plans'
      reset_plan_settings
    when 'all'
      reset_all_settings
    else
      return render json: { error: 'Invalid setting type' }, status: :bad_request
    end

    log_admin_action('settings_reset', { type: setting_type })

    render json: { message: "#{setting_type.capitalize} settings reset to defaults" }
  end

  def export
    format = params[:format] || 'json'
    
    case format.downcase
    when 'json'
      render json: all_settings
    when 'yaml'
      require 'yaml'
      send_data all_settings.to_yaml, 
                filename: "settings_#{Date.current}.yaml", 
                type: 'application/x-yaml'
    else
      render json: { error: 'Unsupported format' }, status: :bad_request
    end
  end

  def import
    return render json: { error: 'No file provided' }, status: :bad_request unless params[:file]

    file = params[:file]
    format = params[:format] || 'json'
    
    begin
      case format.downcase
      when 'json'
        settings_data = JSON.parse(file.read)
      when 'yaml'
        require 'yaml'
        settings_data = YAML.safe_load(file.read)
      else
        return render json: { error: 'Unsupported format' }, status: :bad_request
      end

      import_settings(settings_data)
      
      log_admin_action('settings_imported', { 
        format: format,
        filename: file.original_filename
      })

      render json: { message: 'Settings imported successfully' }
    rescue => e
      log_admin_action('settings_import_failed', { 
        error: e.message,
        filename: file.original_filename
      })
      
      render json: { error: "Import failed: #{e.message}" }, status: :bad_request
    end
  end

  private

  def system_settings
    {
      app_name: Rails.application.class.module_parent.name,
      app_version: '1.0.0',
      maintenance_mode: false,
      debug_mode: Rails.env.development?,
      max_users: 10000,
      max_instagram_accounts_per_user: 5,
      max_automations_per_user: 10,
      session_timeout: 24.hours.to_i,
      file_upload_max_size: 10.megabytes,
      supported_languages: ['en', 'es', 'fr', 'de'],
      timezone: 'UTC',
      date_format: '%Y-%m-%d',
      time_format: '%H:%M:%S'
    }
  end

  def security_settings
    {
      password_min_length: 6,
      password_require_uppercase: true,
      password_require_lowercase: true,
      password_require_numbers: true,
      password_require_symbols: false,
      max_login_attempts: 5,
      account_lockout_duration: 30.minutes.to_i,
      jwt_expiration: 24.hours.to_i,
      jwt_refresh_expiration: 7.days.to_i,
      require_email_verification: true,
      two_factor_authentication: false,
      ip_whitelist_enabled: false,
      ip_whitelist: [],
      suspicious_activity_detection: true,
      auto_suspend_suspicious_accounts: false,
      admin_session_timeout: 8.hours.to_i
    }
  end

  def email_settings
    {
      smtp_enabled: true,
      smtp_host: ENV['SMTP_HOST'] || 'localhost',
      smtp_port: ENV['SMTP_PORT']&.to_i || 587,
      smtp_username: ENV['SMTP_USERNAME'] || '',
      smtp_password: '[PROTECTED]',
      smtp_authentication: 'plain',
      smtp_enable_starttls_auto: true,
      from_email: ENV['FROM_EMAIL'] || 'noreply@kuposu.co',
      from_name: 'Kuposu',
      welcome_email_enabled: true,
      notification_emails_enabled: true,
      marketing_emails_enabled: true,
      email_templates: {
        welcome: 'Welcome to Kuposu!',
        password_reset: 'Reset your password',
        account_suspended: 'Your account has been suspended'
      }
    }
  end

  def integration_settings
    {
      instagram_api_enabled: true,
      instagram_client_id: ENV['INSTAGRAM_CLIENT_ID'] || '',
      instagram_client_secret: '[PROTECTED]',
      instagram_redirect_uri: ENV['INSTAGRAM_REDIRECT_URI'] || '',
      instagram_api_version: 'v19.0',
      webhook_enabled: true,
      webhook_url: ENV['WEBHOOK_URL'] || '',
      webhook_secret: '[PROTECTED]',
      third_party_integrations: {
        zapier: false,
        make: false,
        google_analytics: false,
        facebook_pixel: false
      },
      api_rate_limiting: true,
      api_key_required: false
    }
  end

  def rate_limit_settings
    {
      api_requests_per_minute: 60,
      api_requests_per_hour: 1000,
      api_requests_per_day: 10000,
      dm_sending_rate_limit: 30,
      dm_sending_rate_period: 'per_hour',
      contact_scraping_rate_limit: 100,
      contact_scraping_rate_period: 'per_hour',
      instagram_api_calls_per_hour: 200,
      failed_login_attempts_limit: 5,
      failed_login_attempts_period: 'per_hour',
      account_creation_limit: 10,
      account_creation_period: 'per_day'
    }
  end

  def plan_settings
    {
      free_plan: {
        name: 'Free',
        price: 0,
        dm_limit: 1000,
        contact_limit: 1000,
        instagram_accounts_limit: 1,
        automations_limit: 3,
        features: ['basic_dm_automation', 'contact_scraping']
      },
      pro_plan: {
        name: 'Pro',
        price: 29,
        dm_limit: -1, # Unlimited
        contact_limit: -1, # Unlimited
        instagram_accounts_limit: 5,
        automations_limit: -1, # Unlimited
        features: ['advanced_dm_automation', 'bulk_contact_scraping', 'analytics', 'priority_support']
      },
      custom_plan: {
        name: 'Custom',
        price: 0, # Variable
        dm_limit: 0, # Variable
        contact_limit: 0, # Variable
        instagram_accounts_limit: 0, # Variable
        automations_limit: 0, # Variable
        features: []
      },
      trial_period_days: 7,
      refund_period_days: 30,
      proration_enabled: true,
      auto_downgrade_enabled: true
    }
  end

  def update_system_setting(key, value)
    # In a real application, you'd store these in a settings table or configuration system
    # For now, we'll just validate and log the changes
    valid_system_keys = %w[
      app_name app_version maintenance_mode debug_mode max_users
      max_instagram_accounts_per_user max_automations_per_user session_timeout
      file_upload_max_size timezone date_format time_format
    ]
    
    unless valid_system_keys.include?(key)
      raise ArgumentError, "Invalid system setting key: #{key}"
    end

    # Here you would typically save to a settings model or configuration system
    Rails.logger.info "System setting updated: #{key} = #{value}"
  end

  def update_security_setting(key, value)
    valid_security_keys = %w[
      password_min_length password_require_uppercase password_require_lowercase
      password_require_numbers password_require_symbols max_login_attempts
      account_lockout_duration jwt_expiration jwt_refresh_expiration
      require_email_verification two_factor_authentication ip_whitelist_enabled
      suspicious_activity_detection auto_suspend_suspicious_accounts admin_session_timeout
    ]
    
    unless valid_security_keys.include?(key)
      raise ArgumentError, "Invalid security setting key: #{key}"
    end

    Rails.logger.info "Security setting updated: #{key} = #{value}"
  end

  def update_email_setting(key, value)
    valid_email_keys = %w[
      smtp_enabled smtp_host smtp_port smtp_username smtp_authentication
      smtp_enable_starttls_auto from_email from_name welcome_email_enabled
      notification_emails_enabled marketing_emails_enabled
    ]
    
    unless valid_email_keys.include?(key)
      raise ArgumentError, "Invalid email setting key: #{key}"
    end

    Rails.logger.info "Email setting updated: #{key} = #{value}"
  end

  def update_integration_setting(key, value)
    valid_integration_keys = %w[
      instagram_api_enabled instagram_client_id instagram_redirect_uri
      instagram_api_version webhook_enabled webhook_url api_rate_limiting
      api_key_required
    ]
    
    unless valid_integration_keys.include?(key)
      raise ArgumentError, "Invalid integration setting key: #{key}"
    end

    Rails.logger.info "Integration setting updated: #{key} = #{value}"
  end

  def update_rate_limit_setting(key, value)
    valid_rate_limit_keys = %w[
      api_requests_per_minute api_requests_per_hour api_requests_per_day
      dm_sending_rate_limit dm_sending_rate_period contact_scraping_rate_limit
      contact_scraping_rate_period instagram_api_calls_per_hour
      failed_login_attempts_limit failed_login_attempts_period
      account_creation_limit account_creation_period
    ]
    
    unless valid_rate_limit_keys.include?(key)
      raise ArgumentError, "Invalid rate limit setting key: #{key}"
    end

    Rails.logger.info "Rate limit setting updated: #{key} = #{value}"
  end

  def update_plan_setting(key, value)
    valid_plan_keys = %w[
      trial_period_days refund_period_days proration_enabled auto_downgrade_enabled
    ]
    
    unless valid_plan_keys.include?(key)
      raise ArgumentError, "Invalid plan setting key: #{key}"
    end

    Rails.logger.info "Plan setting updated: #{key} = #{value}"
  end

  def reset_system_settings
    Rails.logger.info "System settings reset to defaults"
  end

  def reset_security_settings
    Rails.logger.info "Security settings reset to defaults"
  end

  def reset_email_settings
    Rails.logger.info "Email settings reset to defaults"
  end

  def reset_integration_settings
    Rails.logger.info "Integration settings reset to defaults"
  end

  def reset_rate_limit_settings
    Rails.logger.info "Rate limit settings reset to defaults"
  end

  def reset_plan_settings
    Rails.logger.info "Plan settings reset to defaults"
  end

  def reset_all_settings
    reset_system_settings
    reset_security_settings
    reset_email_settings
    reset_integration_settings
    reset_rate_limit_settings
    reset_plan_settings
    Rails.logger.info "All settings reset to defaults"
  end

  def all_settings
    {
      system: system_settings,
      security: security_settings,
      email: email_settings,
      integration: integration_settings,
      rate_limits: rate_limit_settings,
      plans: plan_settings
    }
  end

  def import_settings(settings_data)
    settings_data.each do |type, type_settings|
      next unless %w[system security email integration rate_limits plans].include?(type)
      
      type_settings.each do |key, value|
        case type
        when 'system'
          update_system_setting(key, value)
        when 'security'
          update_security_setting(key, value)
        when 'email'
          update_email_setting(key, value)
        when 'integration'
          update_integration_setting(key, value)
        when 'rate_limits'
          update_rate_limit_setting(key, value)
        when 'plans'
          update_plan_setting(key, value)
        end
      end
    end
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