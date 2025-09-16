# Torrust MacTracker

A complete BitTorrent tracker system with modern web interface, built with Rust and Vue.js.

## 🚀 Quick Start

### Local Development
```bash
# Start all services locally
./start-local.sh
```

### Production Deployment
```bash
# Deploy to production
./deploy.sh production
```

## 📁 Project Structure

```
Torrust_MacTracker/
├── torrust-tracker/     # BitTorrent tracker (Rust)
├── torrust-index/       # Backend API (Rust)
├── torrust-index-gui/   # Frontend (Vue.js/Nuxt)
├── docker-compose.yml   # Docker orchestration
├── nginx.conf          # Reverse proxy config
├── deploy.sh           # Deployment script
└── env.production      # Environment variables
```

## 🔧 Services

- **Tracker**: UDP (6969), HTTP (7070), API (1212)
- **Index API**: REST API (3001), Stats (3002)
- **Frontend**: Web interface (3000)
- **Nginx**: Reverse proxy (80, 443)

## 🌐 Access Points

- **Main Interface**: http://localhost:3000
- **API Documentation**: http://localhost:3001/v1/
- **Tracker Stats**: http://localhost:1212/api/v1/stats

## 🛠 Development Workflow

1. **Make changes locally**
2. **Test locally** (services running on localhost)
3. **Commit and push** to Git
4. **Deploy to cloud** with `./deploy.sh production`

## 📦 Deployment

### Prerequisites
- Docker and Docker Compose
- Git repository access
- Cloud server with Docker

### Setup
1. Clone repository on your cloud server
2. Copy `env.production` and configure variables
3. Run `./deploy.sh production`

### Updates
```bash
# Pull latest changes and redeploy
git pull origin main
./deploy.sh production
```

## 🔐 Security

- Generate secure tokens in `env.production`
- Use HTTPS in production (configure SSL in nginx.conf)
- Set up proper firewall rules
- Regular security updates

## 📝 Configuration

Edit `env.production` for:
- Domain settings
- Database configuration
- Email settings
- Security tokens

## 🆘 Troubleshooting

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop all services
docker-compose down

# Rebuild and start
docker-compose up --build -d
```

## 📄 License

This project is licensed under the AGPL-3.0 License.
