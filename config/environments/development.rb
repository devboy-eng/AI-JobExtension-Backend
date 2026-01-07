Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_record.verbose_query_logs = true
  config.active_support.deprecation = :log
  # Temporarily disabled to allow admin panel access
  # config.active_record.migration_error = :page_load
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.hosts.clear
end