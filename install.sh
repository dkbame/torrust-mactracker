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
apt install -y curl wget git vim htop unzip software-properties-common ufw fail2ban

# Install Docker
log "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
log "🐳 Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js
log "📦 Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install Nginx
log "🌐 Installing Nginx..."
apt install -y nginx

# Install Certbot
log "🔒 Installing Certbot for SSL..."
apt install -y certbot python3-certbot-nginx

# Create project directory
log "📁 Creating project directory..."
mkdir -p /opt/torrust-admin
cd /opt/torrust-admin

# Generate secure tokens
log "🔐 Generating secure tokens..."
TRACKER_TOKEN=$(openssl rand -base64 32)
AUTH_SECRET_KEY=$(openssl rand -base64 32)

# Create environment file
log "⚙️ Creating environment configuration..."
cat > .env << EOF
# Torrust Configuration
TRACKER_TOKEN=${TRACKER_TOKEN}
AUTH_SECRET_KEY=${AUTH_SECRET_KEY}

# Database
DATABASE_URL=sqlite:///var/lib/torrust/index/data.db

# Domain (update this with your actual domain)
DOMAIN=your-domain.com

# SSL
SSL_EMAIL=admin@your-domain.com

# Web Admin
ADMIN_PORT=3000
ADMIN_SECRET=$(openssl rand -base64 32)
EOF

# Create Docker Compose file
log "🐳 Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Torrust Tracker
  tracker:
    image: torrust/torrust-tracker:latest
    container_name: torrust-tracker
    restart: unless-stopped
    ports:
      - "6969:6969/udp"    # UDP tracker
      - "7070:7070"        # HTTP tracker
      - "1212:1212"        # Management API
    volumes:
      - tracker_data:/var/lib/torrust/tracker
    environment:
      - TORRUST_TRACKER_CONFIG_TOML_PATH=/etc/torrust/tracker/tracker.development.sqlite3.toml
      - TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER=sqlite3
    networks:
      - torrust-network

  # Torrust Index (Backend API)
  index:
    image: torrust/torrust-index:latest
    container_name: torrust-index
    restart: unless-stopped
    ports:
      - "3001:3001"        # API
      - "3002:3002"        # Statistics importer
    volumes:
      - index_data:/var/lib/torrust/index
    environment:
      - TORRUST_INDEX_CONFIG_TOML_PATH=/etc/torrust/index/index.development.sqlite3.toml
      - TORRUST_INDEX_DATABASE_DRIVER=sqlite3
      - TORRUST_INDEX_API_CORS_PERMISSIVE=1
      - TORRUST_INDEX_CONFIG_OVERRIDE_TRACKER__TOKEN=${TRACKER_TOKEN}
      - TORRUST_INDEX_CONFIG_OVERRIDE_AUTH__SECRET_KEY=${AUTH_SECRET_KEY}
    depends_on:
      - tracker
    networks:
      - torrust-network

  # Torrust Index GUI (Frontend)
  gui:
    image: torrust/torrust-index-gui:latest
    container_name: torrust-gui
    restart: unless-stopped
    ports:
      - "3000:3000"        # Web interface
    environment:
      - NUXT_PUBLIC_API_BASE=http://index:3001/v1
      - NITRO_HOST=0.0.0.0
      - NITRO_PORT=3000
    depends_on:
      - index
    networks:
      - torrust-network

  # Web Admin Backend
  web-admin:
    build: ./web-admin
    container_name: torrust-web-admin
    restart: unless-stopped
    ports:
      - "8080:8080"        # Web admin interface
    environment:
      - NODE_ENV=production
      - ADMIN_SECRET=${ADMIN_SECRET}
      - TRACKER_TOKEN=${TRACKER_TOKEN}
      - AUTH_SECRET_KEY=${AUTH_SECRET_KEY}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - tracker
      - index
      - gui
    networks:
      - torrust-network

volumes:
  tracker_data:
  index_data:

networks:
  torrust-network:
    driver: bridge
EOF

# Create Web Admin directory structure
log "📁 Creating Web Admin structure..."
mkdir -p web-admin/{src,public,views}

# Create package.json for Web Admin
cat > web-admin/package.json << 'EOF'
{
  "name": "torrust-web-admin",
  "version": "1.0.0",
  "description": "Torrust Web Administration Interface",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "ejs": "^3.1.9",
    "dockerode": "^4.0.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "multer": "^1.4.5-lts.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
EOF

# Create Web Admin main application
cat > web-admin/src/app.js << 'EOF'
const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const Docker = require('dockerode');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(cors());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files
app.use(express.static(path.join(__dirname, '../public')));

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));

// Docker client
const docker = new Docker();

// Routes
app.get('/', (req, res) => {
  res.render('dashboard', { 
    title: 'Torrust Admin Dashboard',
    services: ['tracker', 'index', 'gui', 'web-admin']
  });
});

// API Routes
app.get('/api/status', async (req, res) => {
  try {
    const containers = await docker.listContainers({ all: true });
    const torrustContainers = containers.filter(container => 
      container.Names.some(name => name.includes('torrust'))
    );
    
    res.json({
      success: true,
      containers: torrustContainers.map(container => ({
        name: container.Names[0].replace('/', ''),
        status: container.Status,
        state: container.State,
        ports: container.Ports
      }))
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/container/:name/:action', async (req, res) => {
  try {
    const { name, action } = req.params;
    const container = docker.getContainer(name);
    
    switch (action) {
      case 'start':
        await container.start();
        break;
      case 'stop':
        await container.stop();
        break;
      case 'restart':
        await container.restart();
        break;
      default:
        return res.status(400).json({ success: false, error: 'Invalid action' });
    }
    
    res.json({ success: true, message: `Container ${name} ${action}ed successfully` });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Torrust Web Admin running on port ${PORT}`);
});
EOF

# Create Web Admin Dockerfile
cat > web-admin/Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/
COPY views/ ./views/
COPY public/ ./public/

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 8080

CMD ["npm", "start"]
EOF

# Create dashboard view
cat > web-admin/views/dashboard.ejs << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %></title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
</head>
<body class="bg-gray-100">
    <div class="min-h-screen">
        <!-- Header -->
        <header class="bg-white shadow">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div class="flex justify-between items-center py-6">
                    <div class="flex items-center">
                        <i class="fas fa-server text-blue-600 text-2xl mr-3"></i>
                        <h1 class="text-3xl font-bold text-gray-900">Torrust Admin</h1>
                    </div>
                    <div class="flex items-center space-x-4">
                        <button id="refreshBtn" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                            <i class="fas fa-sync-alt mr-2"></i>Refresh
                        </button>
                    </div>
                </div>
            </div>
        </header>

        <!-- Main Content -->
        <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
            <!-- Services Status -->
            <div class="bg-white shadow rounded-lg mb-6">
                <div class="px-4 py-5 sm:p-6">
                    <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Services Status</h3>
                    <div id="servicesContainer" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        <!-- Services will be loaded here -->
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                    <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Quick Actions</h3>
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <button onclick="startAllServices()" class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700">
                            <i class="fas fa-play mr-2"></i>Start All
                        </button>
                        <button onclick="stopAllServices()" class="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700">
                            <i class="fas fa-stop mr-2"></i>Stop All
                        </button>
                        <button onclick="restartAllServices()" class="bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700">
                            <i class="fas fa-redo mr-2"></i>Restart All
                        </button>
                    </div>
                </div>
            </div>
        </main>
    </div>

    <script>
        // Load services status
        async function loadServices() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                if (data.success) {
                    displayServices(data.containers);
                }
            } catch (error) {
                console.error('Error loading services:', error);
            }
        }

        // Display services
        function displayServices(containers) {
            const container = document.getElementById('servicesContainer');
            container.innerHTML = '';

            containers.forEach(service => {
                const statusColor = service.state === 'running' ? 'green' : 'red';
                const statusIcon = service.state === 'running' ? 'fa-check-circle' : 'fa-times-circle';
                
                container.innerHTML += `
                    <div class="bg-gray-50 p-4 rounded-lg">
                        <div class="flex items-center justify-between">
                            <div>
                                <h4 class="font-medium text-gray-900">${service.name}</h4>
                                <p class="text-sm text-gray-500">${service.status}</p>
                            </div>
                            <div class="flex items-center space-x-2">
                                <i class="fas ${statusIcon} text-${statusColor}-500"></i>
                                <div class="flex space-x-1">
                                    <button onclick="controlService('${service.name}', 'start')" class="text-green-600 hover:text-green-800">
                                        <i class="fas fa-play"></i>
                                    </button>
                                    <button onclick="controlService('${service.name}', 'stop')" class="text-red-600 hover:text-red-800">
                                        <i class="fas fa-stop"></i>
                                    </button>
                                    <button onclick="controlService('${service.name}', 'restart')" class="text-yellow-600 hover:text-yellow-800">
                                        <i class="fas fa-redo"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            });
        }

        // Control individual service
        async function controlService(name, action) {
            try {
                const response = await fetch(`/api/container/${name}/${action}`, {
                    method: 'POST'
                });
                const data = await response.json();
                
                if (data.success) {
                    setTimeout(loadServices, 1000); // Refresh after 1 second
                } else {
                    alert('Error: ' + data.error);
                }
            } catch (error) {
                console.error('Error controlling service:', error);
                alert('Error controlling service');
            }
        }

        // Control all services
        async function startAllServices() {
            const containers = ['torrust-tracker', 'torrust-index', 'torrust-gui', 'torrust-web-admin'];
            for (const container of containers) {
                await controlService(container, 'start');
            }
        }

        async function stopAllServices() {
            const containers = ['torrust-tracker', 'torrust-index', 'torrust-gui', 'torrust-web-admin'];
            for (const container of containers) {
                await controlService(container, 'stop');
            }
        }

        async function restartAllServices() {
            const containers = ['torrust-tracker', 'torrust-index', 'torrust-gui', 'torrust-web-admin'];
            for (const container of containers) {
                await controlService(container, 'restart');
            }
        }

        // Event listeners
        document.getElementById('refreshBtn').addEventListener('click', loadServices);

        // Load services on page load
        loadServices();
        
        // Auto-refresh every 30 seconds
        setInterval(loadServices, 30000);
    </script>
</body>
</html>
EOF

# Create Nginx configuration
log "🌐 Creating Nginx configuration..."
cat > /etc/nginx/sites-available/torrust << 'EOF'
server {
    listen 80;
    server_name _;

    # Web Admin
    location /admin {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Torrust GUI
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API
    location /api {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/torrust /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Start services
log "🚀 Starting services..."
systemctl start nginx
systemctl enable nginx

# Start Docker Compose
docker-compose up -d

# Configure firewall
log "🔥 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 6969/udp
ufw allow 7070

# Create systemd service for auto-start
log "⚙️ Creating systemd service..."
cat > /etc/systemd/system/torrust-admin.service << 'EOF'
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

systemctl daemon-reload
systemctl enable torrust-admin.service

# Final status check
log "🔍 Checking service status..."
sleep 10
docker-compose ps

log "✅ Installation completed successfully!"
log ""
log "🌐 Access your Torrust installation:"
log "   • Main Site: http://$(curl -s ifconfig.me)"
log "   • Web Admin: http://$(curl -s ifconfig.me)/admin"
log ""
log "🔧 Next steps:"
log "   1. Update DOMAIN in /opt/torrust-admin/.env"
log "   2. Run: certbot --nginx -d your-domain.com"
log "   3. Access the web admin to manage services"
log ""
log "📋 Useful commands:"
log "   • View logs: docker-compose logs -f"
log "   • Restart: docker-compose restart"
log "   • Stop: docker-compose down"
log "   • Start: docker-compose up -d"
