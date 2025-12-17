require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"

Bundler.require(*Rails.groups)

module InstagramAutomation
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    
    # Fix autoloading for models
    config.eager_load_paths += %W(#{config.root}/app/models)
    
    # Initialize logger early to fix console issue
    config.logger = ActiveSupport::Logger.new(STDOUT)
    config.log_level = :info
    
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'http://localhost:3000', 'https://37bc933303f0.ngrok-free.app'
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true
      end
    end
  end
end