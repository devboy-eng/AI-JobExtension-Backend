require 'net/http'
require 'json'
require 'uri'
require 'jwt'

# Test the coin transactions API endpoint
def test_transactions_api
  # Get a user and their auth token
  user = User.first
  if user.nil?
    puts "No users found in database"
    return
  end

  # Generate auth token for the user
  token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base, 'HS256')

  puts "Testing with user: #{user.email}"
  puts "Current balance: #{user.coin_balance}"
  puts "\nMaking API request to /api/v1/coins/transactions..."

  # Make request to API endpoint
  uri = URI.parse("http://localhost:4003/api/v1/coins/transactions")
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"

  response = http.request(request)

  puts "Response status: #{response.code}"
  puts "Response body:"

  if response.code == "200"
    data = JSON.parse(response.body)
    puts JSON.pretty_generate(data)

    if data["transactions"] && data["transactions"].any?
      puts "\n✅ API is working! Found #{data['transactions'].count} transactions"
    else
      puts "\n✅ API is working! No transactions found for this user"
    end
  else
    puts response.body
    puts "\n❌ API returned error"
  end
end

# Also test the legacy endpoint
def test_legacy_endpoint
  user = User.first
  token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base, 'HS256')

  puts "\n\nTesting legacy endpoint /api/coins/transactions..."

  uri = URI.parse("http://localhost:4003/api/coins/transactions")
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"

  response = http.request(request)

  puts "Response status: #{response.code}"

  if response.code == "200"
    data = JSON.parse(response.body)
    puts JSON.pretty_generate(data)
    puts "\n✅ Legacy API is also working!"
  else
    puts response.body
    puts "\n❌ Legacy API returned error"
  end
end

test_transactions_api
test_legacy_endpoint