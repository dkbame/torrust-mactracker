# 🚀 Torrust Web Admin - One-Click Installer

A comprehensive web administration interface for Torrust with one-click installation on fresh Ubuntu servers.

## ✨ Features

- **🎯 One-Click Installation** - Automated setup on fresh Ubuntu servers
- **🌐 Web Admin Interface** - Modern, responsive dashboard for service management
- **🐳 Docker Integration** - Uses official Torrust Docker images
- **🔒 SSL Support** - Automatic Let's Encrypt certificate setup
- **📊 Service Monitoring** - Real-time status monitoring and control
- **⚡ Quick Actions** - Start/stop/restart services with one click
- **🔧 Easy Configuration** - Environment-based configuration management

## 🏗️ Architecture

### Services Included:
- **Torrust Tracker** - BitTorrent tracker service
- **Torrust Index** - Backend API and database
- **Torrust GUI** - Frontend web interface
- **Web Admin** - Management dashboard (Node.js/Express)
- **Nginx** - Reverse proxy and load balancer

### Technology Stack:
- **Backend**: Node.js + Express
- **Frontend**: EJS + Tailwind CSS
- **Containerization**: Docker + Docker Compose
- **Reverse Proxy**: Nginx
- **SSL**: Let's Encrypt (Certbot)
- **Database**: SQLite (default)

## 🚀 Quick Start

### Prerequisites
- Fresh Ubuntu 20.04+ server
- Root access
- Domain name (for SSL setup)

### Installation

1. **Connect to your server:**
   ```bash
   ssh root@your-server-ip
   ```

2. **Clone and run the installer:**
   ```bash
   git clone https://github.com/dkbame/torrust-mactracker.git
   cd torrust-mactracker
   chmod +x install.sh
   ./install.sh
   ```

3. **Access your installation:**
   - **Main Site**: `http://your-server-ip`
   - **Web Admin**: `http://your-server-ip/admin`

4. **Setup SSL (optional):**
   ```bash
   # Update domain in .env file
   nano /opt/torrust-admin/.env
   
   # Get SSL certificate
   certbot --nginx -d your-domain.com
   ```

## 🔧 Configuration

### Environment Variables
Edit `/opt/torrust-admin/.env`:

```bash
# Torrust Configuration
TRACKER_TOKEN=your-secure-token
AUTH_SECRET_KEY=your-secure-key

# Domain
DOMAIN=your-domain.com

# SSL
SSL_EMAIL=admin@your-domain.com

# Web Admin
ADMIN_PORT=3000
ADMIN_SECRET=your-admin-secret
```

### Service Management

**Using Web Admin:**
- Access `http://your-domain/admin`
- Use the dashboard to start/stop/restart services
- Monitor real-time status

**Using Command Line:**
```bash
cd /opt/torrust-admin

# View status
docker-compose ps

# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart specific service
docker-compose restart tracker
```

## 📊 Web Admin Features

### Dashboard
- **Service Status** - Real-time monitoring of all services
- **Quick Actions** - Start/stop/restart all services
- **Individual Control** - Manage each service separately
- **Auto-refresh** - Status updates every 30 seconds

### Service Management
- **Start/Stop/Restart** - Control individual services
- **Status Monitoring** - View running status and ports
- **Log Access** - View service logs (coming soon)
- **Configuration** - Update settings (coming soon)

## 🔒 Security Features

- **Firewall Configuration** - UFW with necessary ports only
- **Rate Limiting** - API rate limiting protection
- **Helmet Security** - Security headers
- **SSL/TLS** - Automatic HTTPS setup
- **Fail2ban** - Intrusion prevention

## 📁 File Structure

```
/opt/torrust-admin/
├── .env                    # Environment configuration
├── docker-compose.yml      # Docker services configuration
├── web-admin/             # Web admin application
│   ├── src/
│   │   └── app.js         # Express application
│   ├── views/
│   │   └── dashboard.ejs  # Dashboard template
│   ├── package.json       # Node.js dependencies
│   └── Dockerfile         # Web admin container
└── install.sh             # Installation script
```

## 🛠️ Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check Docker status
systemctl status docker

# Check logs
docker-compose logs

# Restart Docker
systemctl restart docker
```

**Web admin not accessible:**
```bash
# Check if containers are running
docker-compose ps

# Check Nginx status
systemctl status nginx

# Check firewall
ufw status
```

**SSL certificate issues:**
```bash
# Test certificate
certbot certificates

# Renew certificate
certbot renew

# Check Nginx configuration
nginx -t
```

### Logs

**View all logs:**
```bash
docker-compose logs -f
```

**View specific service logs:**
```bash
docker-compose logs -f tracker
docker-compose logs -f index
docker-compose logs -f gui
docker-compose logs -f web-admin
```

## 🔄 Updates

**Update Torrust services:**
```bash
cd /opt/torrust-admin
docker-compose pull
docker-compose up -d
```

**Update Web Admin:**
```bash
cd /opt/torrust-admin/web-admin
git pull
docker-compose build web-admin
docker-compose up -d web-admin
```

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/dkbame/torrust-mactracker/issues)
- **Documentation**: [Torrust Docs](https://docs.torrust.com)
- **Community**: [Torrust Discord](https://discord.gg/torrust)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 🙏 Acknowledgments

- [Torrust](https://github.com/torrust) - The amazing BitTorrent tracker
- [Docker](https://docker.com) - Containerization platform
- [Node.js](https://nodejs.org) - JavaScript runtime
- [Express](https://expressjs.com) - Web framework
