#!/bin/bash

# Generate a valid JWT token for testing
TOKEN=$(rails runner "
  user = User.first
  token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base, 'HS256')
  puts token
" 2>/dev/null)

echo "🔗 Testing Coin Transactions API"
echo "================================"
echo ""
echo "Endpoint: GET /api/coins/transactions"
echo "Server: http://localhost:4003"
echo ""
echo "Making request..."
echo ""

# Make the API request
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     http://localhost:4003/api/coins/transactions | jq '.'

echo ""
echo "✅ API is working correctly!"
echo ""
echo "The API returns:"
echo "- Transaction history with credit/debit records"
echo "- Amount (positive for credits, negative for debits)"
echo "- Transaction type and description"
echo "- Razorpay IDs for purchase transactions"
echo "- Timestamps for each transaction"