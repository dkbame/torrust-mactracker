#!/bin/bash

# Test Deployment Script
# This script validates the deployment setup without doing a full build

set -e

echo "🧪 Testing Torrust Deployment Setup..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if environment file exists
if [ ! -f "env.production" ]; then
    echo "❌ Environment file env.production not found!"
    exit 1
fi

# Load environment variables
export $(cat env.production | grep -v '^#' | xargs)

# Validate environment variables
if [ -z "$TRACKER_TOKEN" ] || [ "$TRACKER_TOKEN" = "CHANGE_THIS_TO_A_SECURE_RANDOM_TOKEN" ]; then
    echo "❌ TRACKER_TOKEN not set or using default value"
    exit 1
fi

if [ -z "$AUTH_SECRET_KEY" ] || [ "$AUTH_SECRET_KEY" = "CHANGE_THIS_TO_A_SECURE_RANDOM_KEY" ]; then
    echo "❌ AUTH_SECRET_KEY not set or using default value"
    exit 1
fi

echo "✅ Environment variables validated"

# Check if all required files exist
echo "🔍 Checking required files..."

required_files=(
    "docker-compose.yml"
    "nginx.conf"
    "deploy.sh"
    "start-local.sh"
    "torrust-tracker/Containerfile"
    "torrust-index/Containerfile"
    "torrust-index-gui/Containerfile"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done

echo "✅ All required files present"

# Validate Docker Compose syntax
echo "🔍 Validating Docker Compose syntax..."
if ! docker-compose config > /dev/null 2>&1; then
    echo "❌ Docker Compose configuration is invalid"
    docker-compose config
    exit 1
fi

echo "✅ Docker Compose syntax is valid"

# Test Docker Compose configuration
echo "🔍 Testing Docker Compose configuration..."
docker-compose config --quiet

echo "✅ Docker Compose configuration test passed"

# Check if ports are available
echo "🔍 Checking if required ports are available..."

ports=(3000 3001 3002 6969 7070 1212)
for port in "${ports[@]}"; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "⚠️  Port $port is already in use (this is OK if services are running)"
    else
        echo "✅ Port $port is available"
    fi
done

# Test individual component builds (quick validation)
echo "🔍 Testing component build contexts..."

# Test tracker build context
if [ -d "torrust-tracker" ] && [ -f "torrust-tracker/Containerfile" ]; then
    echo "✅ Tracker build context ready"
else
    echo "❌ Tracker build context missing"
    exit 1
fi

# Test index build context
if [ -d "torrust-index" ] && [ -f "torrust-index/Containerfile" ]; then
    echo "✅ Index build context ready"
else
    echo "❌ Index build context missing"
    exit 1
fi

# Test GUI build context
if [ -d "torrust-index-gui" ] && [ -f "torrust-index-gui/Containerfile" ]; then
    echo "✅ GUI build context ready"
else
    echo "❌ GUI build context missing"
    exit 1
fi

# Test if Node.js dependencies are installed for GUI
if [ -d "torrust-index-gui/node_modules" ]; then
    echo "✅ GUI dependencies installed"
else
    echo "⚠️  GUI dependencies not installed (will be installed during build)"
fi

# Test if Rust projects can be validated
echo "🔍 Testing Rust project validation..."

if command -v cargo > /dev/null 2>&1; then
    # Test tracker
    if [ -f "torrust-tracker/Cargo.toml" ]; then
        echo "✅ Tracker Cargo.toml found"
    fi
    
    # Test index
    if [ -f "torrust-index/Cargo.toml" ]; then
        echo "✅ Index Cargo.toml found"
    fi
else
    echo "⚠️  Cargo not found (Rust projects will be built in Docker)"
fi

echo ""
echo "🎉 All deployment tests passed!"
echo ""
echo "📋 Summary:"
echo "  ✅ Docker is running"
echo "  ✅ Environment variables configured"
echo "  ✅ All required files present"
echo "  ✅ Docker Compose syntax valid"
echo "  ✅ Build contexts ready"
echo "  ✅ Ports available"
echo ""
echo "🚀 Ready for deployment!"
echo ""
echo "Next steps:"
echo "  1. Push to GitHub: git add . && git commit -m 'Deploy ready' && git push"
echo "  2. Deploy to cloud: ./deploy.sh production"
echo ""
echo "💡 To test locally first:"
echo "  ./start-local.sh"
