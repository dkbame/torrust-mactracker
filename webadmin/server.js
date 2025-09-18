const express = require('express');
const path = require('path');
const { exec, spawn } = require('child_process');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Torrust services configuration
const TORRUST_SERVICES = {
    tracker: {
        name: 'torrust-tracker',
        description: 'BitTorrent Tracker Service',
        ports: ['6969/udp', '7070', '1212'],
        image: 'torrust/torrust-tracker:latest',
        status: 'stopped'
    },
    index: {
        name: 'torrust-index',
        description: 'Backend API and Database',
        ports: ['3001', '3002'],
        image: 'torrust/torrust-index:latest',
        status: 'stopped'
    },
    gui: {
        name: 'torrust-gui',
        description: 'Frontend Web Interface',
        ports: ['3000'],
        image: 'torrust/torrust-index-gui:latest',
        status: 'stopped'
    }
};

// Helper function to execute commands
function executeCommand(command, callback) {
    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing command: ${error}`);
            callback({ success: false, error: error.message, stderr });
        } else {
            callback({ success: true, stdout, stderr });
        }
    });
}

// Check if Docker is available
function checkDocker(callback) {
    executeCommand('docker --version', (result) => {
        if (result.success) {
            executeCommand('docker-compose --version', callback);
        } else {
            callback(result);
        }
    });
}

// API routes
app.get('/api/status', (req, res) => {
    res.json({ 
        status: 'running', 
        message: 'Torrust Web Admin is running!',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/services', (req, res) => {
    // Check Docker status
    checkDocker((dockerResult) => {
        const services = Object.values(TORRUST_SERVICES).map(service => ({
            ...service,
            dockerAvailable: dockerResult.success
        }));
        
        res.json({
            success: true,
            data: services,
            docker: dockerResult
        });
    });
});

app.get('/api/docker/status', (req, res) => {
    checkDocker((result) => {
        res.json(result);
    });
});

app.post('/api/torrust/install', (req, res) => {
    const { services } = req.body;
    
    if (!services || !Array.isArray(services)) {
        return res.status(400).json({ 
            success: false, 
            error: 'Services array is required' 
        });
    }

    // Create Torrust docker-compose.yml
    const dockerComposeContent = `services:
  # Torrust Tracker
  tracker:
    build:
      context: .
      dockerfile: Dockerfile.tracker
    container_name: torrust-tracker
    restart: unless-stopped
    ports:
      - "6969:6969/udp"
      - "7070:7070"
      - "1212:1212"
    volumes:
      - tracker_data:/var/lib/torrust/tracker
    environment:
      - TORRUST_TRACKER_CONFIG_TOML_PATH=/etc/torrust/tracker/tracker.development.sqlite3.toml
      - TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER=sqlite3
    networks:
      - torrust-network

  # Torrust Index
  index:
    build:
      context: .
      dockerfile: Dockerfile.index
    container_name: torrust-index
    restart: unless-stopped
    ports:
      - "3001:3001"
      - "3002:3002"
    volumes:
      - index_data:/var/lib/torrust/index
    environment:
      - TORRUST_INDEX_CONFIG_TOML_PATH=/etc/torrust/index/index.development.sqlite3.toml
      - TORRUST_INDEX_DATABASE_DRIVER=sqlite3
      - TORRUST_INDEX_API_CORS_PERMISSIVE=1
    depends_on:
      - tracker
    networks:
      - torrust-network

  # Torrust GUI
  gui:
    build:
      context: .
      dockerfile: Dockerfile.gui
    container_name: torrust-gui
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NUXT_PUBLIC_API_BASE=http://index:3001/v1
      - NITRO_HOST=0.0.0.0
      - NITRO_PORT=3000
    depends_on:
      - index
    networks:
      - torrust-network

volumes:
  tracker_data:
  index_data:

networks:
  torrust-network:
    driver: bridge`;

    // Write docker-compose.yml
    fs.writeFileSync('/opt/torrust-admin/torrust-docker-compose.yml', dockerComposeContent);
    
    res.json({ 
        success: true, 
        message: 'Torrust configuration created. Ready to start services.',
        services: services
    });
});

app.post('/api/torrust/start', (req, res) => {
    const { service } = req.body;
    
    if (service === 'all') {
        // Start all Torrust services
        executeCommand('cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml up -d', (result) => {
            res.json(result);
        });
    } else {
        // Start specific service
        executeCommand(`cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml up -d ${service}`, (result) => {
            res.json(result);
        });
    }
});

app.post('/api/torrust/stop', (req, res) => {
    const { service } = req.body;
    
    if (service === 'all') {
        // Stop all Torrust services
        executeCommand('cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml down', (result) => {
            res.json(result);
        });
    } else {
        // Stop specific service
        executeCommand(`cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml stop ${service}`, (result) => {
            res.json(result);
        });
    }
});

app.get('/api/torrust/logs/:service', (req, res) => {
    const { service } = req.params;
    
    executeCommand(`cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml logs --tail=100 ${service}`, (result) => {
        res.json(result);
    });
});

app.get('/api/torrust/status', (req, res) => {
    executeCommand('cd /opt/torrust-admin && docker-compose -f torrust-docker-compose.yml ps', (result) => {
        res.json(result);
    });
});

// Add missing logs endpoint for individual services
app.get('/api/services/:name/logs', (req, res) => {
    const { name } = req.params;
    
    // Check if the service exists in our configuration
    if (!TORRUST_SERVICES[name]) {
        return res.json({ 
            success: false, 
            error: `Service ${name} not found` 
        });
    }
    
    // For now, return a placeholder since services aren't running yet
    res.json({ 
        success: true, 
        data: `No logs available for ${name}. Service is not running yet.` 
    });
});

// Serve the main dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Torrust Web Admin running on port ${PORT}`);
});