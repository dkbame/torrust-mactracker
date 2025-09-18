#!/bin/bash

# Torrust Web Admin One-Click Installer
# For fresh Ubuntu server installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "🚀 Starting Torrust Web Admin Installation..."

# Update system
log "📦 Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "🔧 Installing essential packages..."
apt install -y curl wget git vim htop unzip software-properties-common

# Install Docker
log "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
log "🐳 Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js
log "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Create application directory
log "📁 Creating application directory..."
mkdir -p /opt/torrust-admin
cd /opt/torrust-admin

# Clone the repository
log "📥 Cloning Torrust Web Admin repository..."
git clone https://github.com/dkbame/torrust-mactracker.git .

# Copy configuration files
log "📋 Copying configuration files..."
cp docker-compose.yml /opt/torrust-admin/
cp -r nginx /opt/torrust-admin/
cp -r webadmin /opt/torrust-admin/
cp -r config /opt/torrust-admin/

# Create environment file
log "🔐 Creating environment configuration..."
cat > .env << EOF
# Torrust Configuration
TRACKER_TOKEN=$(openssl rand -base64 32)
AUTH_SECRET_KEY=$(openssl rand -base64 32)
ADMIN_SECRET=$(openssl rand -base64 32)

# Domain Configuration (update these)
DOMAIN=your-domain.com
EMAIL=admin@your-domain.com

# SSL Configuration
SSL_EMAIL=admin@your-domain.com
EOF

# Create SSL directory
log "🔒 Setting up SSL directory..."
mkdir -p ssl

# Generate self-signed certificate for initial setup
log "🔐 Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Set proper permissions
log "🔐 Setting permissions..."
chown -R root:root /opt/torrust-admin
chmod -R 755 /opt/torrust-admin
chmod +x *.sh

# Configure firewall
log "🔥 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 6969/udp
ufw allow 7070/tcp
ufw allow 3000/tcp
ufw allow 3001/tcp
ufw allow 8080/tcp

# Start services
log "🚀 Starting Torrust services..."
docker-compose up -d

# Wait for services to start
log "⏳ Waiting for services to start..."
sleep 30

# Check service status
log "📊 Checking service status..."
docker-compose ps

# Create systemd service for auto-start
log "⚙️ Creating systemd service..."
cat > /etc/systemd/system/torrust-admin.service << EOF
[Unit]
Description=Torrust Web Admin
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/torrust-admin
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable torrust-admin.service

# Create update script
log "📝 Creating update script..."
cat > /opt/torrust-admin/update.sh << 'EOF'
#!/bin/bash
cd /opt/torrust-admin
git pull origin main
docker-compose down
docker-compose build --no-cache
docker-compose up -d
EOF

chmod +x /opt/torrust-admin/update.sh

# Display completion message
log "✅ Installation completed successfully!"
echo ""
echo "🎉 Torrust Web Admin is now running!"
echo ""
echo "📊 Access Points:"
echo "   • Main Interface: http://$(curl -s ifconfig.me):3000"
echo "   • Web Admin: http://$(curl -s ifconfig.me):8080"
echo "   • API: http://$(curl -s ifconfig.me):3001"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs: docker-compose logs -f"
echo "   • Restart: docker-compose restart"
echo "   • Stop: docker-compose down"
echo "   • Start: docker-compose up -d"
echo "   • Update: ./update.sh"
echo ""
echo "🔐 Security Notes:"
echo "   • Change default passwords in .env file"
echo "   • Configure SSL certificates for production"
echo "   • Update firewall rules as needed"
echo ""
echo "📚 Documentation: https://github.com/dkbame/torrust-mactracker"
echo ""
log "🚀 Installation complete! Your Torrust Web Admin is ready to use!"