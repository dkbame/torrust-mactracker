#!/bin/bash

# Start Torrust services locally for development
# This keeps your current local development setup

echo "🚀 Starting Torrust services locally..."

# Check if services are already running
if pgrep -f "torrust-tracker" > /dev/null; then
    echo "⚠️  Tracker is already running"
else
    echo "🔧 Starting Tracker..."
    cd torrust-tracker
    mkdir -p ./storage/tracker/lib/database/
    touch ./storage/tracker/lib/database/sqlite3.db
    mkdir -p ./storage/tracker/etc/
    cp ./share/default/config/tracker.development.sqlite3.toml ./storage/tracker/etc/tracker.toml
    
    # Generate token if not exists
    if [ ! -f "./storage/tracker/lib/tracker_api_admin_token.secret" ]; then
        openssl rand -base64 32 > ./storage/tracker/lib/tracker_api_admin_token.secret
        chmod go-rwx ./storage/tracker/lib/tracker_api_admin_token.secret
    fi
    
    TOKEN=$(cat ./storage/tracker/lib/tracker_api_admin_token.secret)
    TORRUST_TRACKER_CONFIG_TOML=$(cat "./storage/tracker/etc/tracker.toml") \
    TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN="$TOKEN" \
    cargo run &
    cd ..
fi

# Wait for tracker to start
sleep 5

if pgrep -f "torrust-index" > /dev/null; then
    echo "⚠️  Index is already running"
else
    echo "🔧 Starting Index..."
    cd torrust-index
    mkdir -p ./storage/index/lib/database/
    touch ./storage/index/lib/database/sqlite3.db
    mkdir -p ./storage/index/etc/
    cp ./share/default/config/index.development.sqlite3.toml ./storage/index/etc/index.toml
    
    TOKEN=$(cat ../torrust-tracker/storage/tracker/lib/tracker_api_admin_token.secret)
    TORRUST_INDEX_CONFIG_TOML=$(cat "./storage/index/etc/index.toml") \
    TORRUST_INDEX_CONFIG_OVERRIDE_TRACKER__TOKEN="$TOKEN" \
    TORRUST_INDEX_CONFIG_OVERRIDE_AUTH__SECRET_KEY="MaxVerstappenWC2021" \
    TORRUST_INDEX_API_CORS_PERMISSIVE=1 \
    cargo run &
    cd ..
fi

# Wait for index to start
sleep 10

if pgrep -f "nuxt" > /dev/null; then
    echo "⚠️  GUI is already running"
else
    echo "🔧 Starting GUI..."
    cd torrust-index-gui
    NUXT_PUBLIC_API_BASE="http://localhost:3001/v1" \
    NITRO_HOST="0.0.0.0" \
    NITRO_PORT="3000" \
    npm run dev &
    cd ..
fi

echo "⏳ Waiting for services to start..."
sleep 15

echo "🎉 All services started!"
echo ""
echo "📊 Service URLs:"
echo "  Frontend: http://127.0.0.1:3000"
echo "  API: http://localhost:3001/v1/"
echo "  Tracker: http://localhost:1212/api/v1/stats"
echo ""
echo "🛑 To stop services:"
echo "  pkill -f torrust-tracker"
echo "  pkill -f torrust-index"
echo "  pkill -f nuxt"
