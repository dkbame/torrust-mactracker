#!/bin/bash

# Torrust Web Admin Update Script
# Updates all services to latest versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    error "Please run this script from the torrust-admin directory"
fi

log "🔄 Starting Torrust Web Admin Update..."

# Create backup
log "💾 Creating backup..."
BACKUP_DIR="/opt/torrust-admin-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /opt/torrust-admin/* "$BACKUP_DIR/"
log "Backup created at: $BACKUP_DIR"

# Pull latest images
log "📥 Pulling latest Docker images..."
docker-compose pull

# Update web admin if needed
if [ -d "web-admin" ]; then
    log "📦 Updating Web Admin dependencies..."
    cd web-admin
    if [ -f "package.json" ]; then
        npm update
    fi
    cd ..
fi

# Rebuild and restart services
log "🔨 Rebuilding and restarting services..."
docker-compose down
docker-compose up -d

# Wait for services to start
log "⏳ Waiting for services to start..."
sleep 15

# Check service status
log "🔍 Checking service status..."
docker-compose ps

# Test web admin
log "🧪 Testing Web Admin..."
if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    log "✅ Web Admin is responding"
else
    warn "⚠️ Web Admin may not be ready yet"
fi

log "✅ Update completed successfully!"
log ""
log "🌐 Access your updated installation:"
log "   • Main Site: http://$(curl -s ifconfig.me)"
log "   • Web Admin: http://$(curl -s ifconfig.me)/admin"
log ""
log "📋 If you encounter any issues:"
log "   • Check logs: docker-compose logs -f"
log "   • Restore backup: cp -r $BACKUP_DIR/* /opt/torrust-admin/"
