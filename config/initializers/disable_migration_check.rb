# Disable migration checking for Job Extension Backend
# This prevents ActiveRecord::PendingMigrationError during admin panel access
Rails.application.configure do
  config.active_record.migration_error = false
end