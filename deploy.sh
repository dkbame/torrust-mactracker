#!/bin/bash

# Torrust Deployment Script
# Usage: ./deploy.sh [environment]
# Example: ./deploy.sh production

set -e

ENVIRONMENT=${1:-production}
COMPOSE_FILE="docker-compose.yml"

echo "🚀 Starting Torrust deployment for $ENVIRONMENT environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if environment file exists
if [ ! -f "env.$ENVIRONMENT" ]; then
    echo "❌ Environment file env.$ENVIRONMENT not found!"
    echo "Please create env.$ENVIRONMENT with your configuration."
    exit 1
fi

# Load environment variables
export $(cat env.$ENVIRONMENT | grep -v '^#' | xargs)

# Generate secure tokens if not set
if [ "$TRACKER_TOKEN" = "CHANGE_THIS_TO_A_SECURE_RANDOM_TOKEN" ]; then
    echo "🔐 Generating secure tracker token..."
    export TRACKER_TOKEN=$(openssl rand -base64 32)
    echo "Generated TRACKER_TOKEN: $TRACKER_TOKEN"
fi

if [ "$AUTH_SECRET_KEY" = "CHANGE_THIS_TO_A_SECURE_RANDOM_KEY" ]; then
    echo "🔐 Generating secure auth secret key..."
    export AUTH_SECRET_KEY=$(openssl rand -base64 32)
    echo "Generated AUTH_SECRET_KEY: $AUTH_SECRET_KEY"
fi

# Pull latest changes from Git
echo "📥 Pulling latest changes from Git..."
git pull origin main

# Build and start services
echo "🔨 Building and starting services..."
docker-compose -f $COMPOSE_FILE down
docker-compose -f $COMPOSE_FILE build --no-cache
docker-compose -f $COMPOSE_FILE up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Health check
echo "🏥 Checking service health..."
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend health check failed"
fi

if curl -f http://localhost:3001/v1/torrents > /dev/null 2>&1; then
    echo "✅ API is healthy"
else
    echo "❌ API health check failed"
fi

if curl -f "http://localhost:1212/api/v1/stats?token=$TRACKER_TOKEN" > /dev/null 2>&1; then
    echo "✅ Tracker is healthy"
else
    echo "❌ Tracker health check failed"
fi

echo "🎉 Deployment completed!"
echo ""
echo "📊 Service URLs:"
echo "  Frontend: http://localhost:3000"
echo "  API: http://localhost:3001/v1/"
echo "  Tracker: http://localhost:1212/api/v1/stats"
echo ""
echo "📝 To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "🛑 To stop services:"
echo "  docker-compose down"
