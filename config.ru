# This file is used by Rack-based servers to start the application.

require_relative "config/application"

Rails.application.initialize!

run Rails.application