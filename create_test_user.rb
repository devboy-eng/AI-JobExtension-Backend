#!/usr/bin/env ruby
require_relative 'config/environment'

# Create a test user if one doesn't exist
unless User.exists?
  user = User.create!(
    name: "Test User",
    email: "test@example.com",
    password_hash: "dummy_hash"
  )
  puts "Created test user: #{user.name} (#{user.email})"
else
  puts "User already exists: #{User.first.name}"
end

puts "Total users: #{User.count}"