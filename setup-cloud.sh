#!/bin/bash

# Cloud Setup Script for Torrust
# Run this on your cloud server after cloning the repository

set -e

echo "🌩️  Setting up Torrust on cloud server..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Please run this script from the torrust-mactracker directory"
    exit 1
fi

# Create environment file
echo "📝 Creating environment file..."
cat > env.production << 'EOF'
# Torrust Production Environment Variables

# Tracker Configuration
TRACKER_TOKEN=TCY6DZRMZg05LE7VV80+f78lweWDzEzj7l8+rPYuCpY=
AUTH_SECRET_KEY=cC5+yU9EPVl0El35wQwfWvM+fFGtum7dqX2XTorm6Js=

# Domain Configuration
DOMAIN=your-domain.com
SSL_EMAIL=your-email@example.com

# Database Configuration (if using external database)
# DATABASE_URL=postgresql://user:password@localhost:5432/torrust

# Email Configuration (optional)
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password

# Security
# Generate these with: openssl rand -base64 32
TRACKER_TOKEN=TCY6DZRMZg05LE7VV80+f78lweWDzEzj7l8+rPYuCpY=
AUTH_SECRET_KEY=cC5+yU9EPVl0El35wQwfWvM+fFGtum7dqX2XTorm6Js=
EOF

echo "✅ Environment file created"

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x deploy.sh
chmod +x start-local.sh
chmod +x test-deployment.sh

echo "✅ Scripts made executable"

# Test the setup
echo "🧪 Testing deployment setup..."
./test-deployment.sh

echo ""
echo "🎉 Cloud setup complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Edit env.production to set your domain and email"
echo "  2. Run: ./deploy.sh production"
echo ""
echo "🌐 After deployment, your site will be available at:"
echo "  - Main Interface: http://your-server-ip:3000"
echo "  - API: http://your-server-ip:3001/v1/"
echo "  - Tracker: http://your-server-ip:1212/api/v1/stats"
