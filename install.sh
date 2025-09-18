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
if [ -d "/opt/torrust-admin" ]; then
    log "📁 Directory exists, removing old installation..."
    rm -rf /opt/torrust-admin
fi
mkdir -p /opt/torrust-admin
cd /opt/torrust-admin

# Clone the repository
log "📥 Cloning Torrust Web Admin repository..."
git clone https://github.com/dkbame/torrust-mactracker.git .

# Create environment file
log "🔐 Creating environment configuration..."
cat > .env << EOF
# Web Admin Configuration
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

# Check for port conflicts and configure firewall
log "🔥 Checking for port conflicts..."

# Check if port 80 is in use
if lsof -i :80 >/dev/null 2>&1; then
    warn "Port 80 is already in use. Web admin will be available on port 8080 only."
    # Update nginx config to use different port
    sed -i 's/listen 80;/listen 8081;/' nginx/nginx.conf
    sed -i 's/listen 443 ssl http2;/listen 8443 ssl http2;/' nginx/nginx.conf
    sed -i 's/80:80/8081:80/' docker-compose.yml
    sed -i 's/443:443/8443:443/' docker-compose.yml
    log "Updated nginx to use ports 8081 (HTTP) and 8443 (HTTPS)"
else
    log "Port 80 is available. Using standard ports."
fi

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 8081/tcp
ufw allow 8443/tcp

# Start services
log "🚀 Starting Web Admin services..."
docker-compose up -d

# Wait for services to start
log "⏳ Waiting for services to start..."
sleep 10

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
if lsof -i :80 >/dev/null 2>&1; then
    echo "   • Web Admin: http://$(curl -s ifconfig.me):8080"
    echo "   • Nginx (HTTP): http://$(curl -s ifconfig.me):8081"
    echo "   • Nginx (HTTPS): https://$(curl -s ifconfig.me):8443"
else
    echo "   • Web Admin: http://$(curl -s ifconfig.me):8080"
    echo "   • Web Admin (HTTPS): https://$(curl -s ifconfig.me)"
fi
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