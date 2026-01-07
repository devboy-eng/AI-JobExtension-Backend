#!/bin/bash

echo "🚀 Starting deployment..."

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Run database migrations
echo "🗃️ Running database migrations..."
rails db:migrate

# Check if migrations were successful
if [ $? -eq 0 ]; then
    echo "✅ Database migrations completed successfully"
else
    echo "❌ Database migrations failed"
    exit 1
fi

echo "🎉 Deployment completed successfully!"