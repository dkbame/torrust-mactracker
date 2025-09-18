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

    // Create installation script
    const installScript = `#!/bin/bash
set -e

echo "🚀 Installing Torrust services..."

# Install Rust if not already installed
if ! command -v cargo &> /dev/null; then
    echo "📦 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
fi

# Install Node.js if not already installed
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Create directories
mkdir -p /opt/torrust-admin/torrust-services/{tracker,index,gui}

# Clone and build Torrust Tracker
if [ -d "/opt/torrust-admin/torrust-services/tracker" ]; then
    echo "🔄 Updating Torrust Tracker..."
    cd /opt/torrust-admin/torrust-services/tracker
    git pull origin main
else
    echo "📥 Cloning Torrust Tracker..."
    cd /opt/torrust-admin/torrust-services
    git clone https://github.com/torrust/torrust-tracker.git tracker
    cd tracker
fi
cargo build --release
echo "✅ Torrust Tracker built successfully!"

# Clone and build Torrust Index
if [ -d "/opt/torrust-admin/torrust-services/index" ]; then
    echo "🔄 Updating Torrust Index..."
    cd /opt/torrust-admin/torrust-services/index
    git pull origin main
else
    echo "📥 Cloning Torrust Index..."
    cd /opt/torrust-admin/torrust-services
    git clone https://github.com/torrust/torrust-index.git index
    cd index
fi
cargo build --release
echo "✅ Torrust Index built successfully!"

# Clone and build Torrust GUI
if [ -d "/opt/torrust-admin/torrust-services/gui" ]; then
    echo "🔄 Updating Torrust GUI..."
    cd /opt/torrust-admin/torrust-services/gui
    git pull origin main
else
    echo "📥 Cloning Torrust GUI..."
    cd /opt/torrust-admin/torrust-services
    git clone https://github.com/torrust/torrust-index-gui.git gui
    cd gui
fi
npm install
npm run build
echo "✅ Torrust GUI built successfully!"

echo "🎉 All Torrust services installed successfully!"
`;

    // Write installation script
    fs.writeFileSync('/opt/torrust-admin/install-torrust.sh', installScript);
    
    // Make it executable
    executeCommand('chmod +x /opt/torrust-admin/install-torrust.sh', (result) => {
        if (result.success) {
            // Run the installation script
            executeCommand('cd /opt/torrust-admin && ./install-torrust.sh', (installResult) => {
                if (installResult.success) {
                    res.json({ 
                        success: true, 
                        message: 'Torrust services installed successfully! Ready to start.',
                        services: services,
                        output: installResult.stdout
                    });
                } else {
                    res.json({ 
                        success: false, 
                        error: 'Installation failed: ' + installResult.error,
                        output: installResult.stderr
                    });
                }
            });
        } else {
            res.json({ 
                success: false, 
                error: 'Failed to make installation script executable' 
            });
        }
    });
});

app.post('/api/torrust/start', (req, res) => {
    const { service } = req.body;
    
    if (service === 'all') {
        // Start all Torrust services
        const startScript = `#!/bin/bash
cd /opt/torrust-admin

# Start Torrust Tracker
echo "🚀 Starting Torrust Tracker..."
cd torrust-services/tracker
nohup ./target/release/torrust-tracker > /opt/torrust-admin/logs/tracker.log 2>&1 &
echo $! > /opt/torrust-admin/tracker.pid
cd ..

# Start Torrust Index
echo "🚀 Starting Torrust Index..."
cd index
nohup ./target/release/torrust-index > /opt/torrust-admin/logs/index.log 2>&1 &
echo $! > /opt/torrust-admin/index.pid
cd ..

# Start Torrust GUI
echo "🚀 Starting Torrust GUI..."
cd gui
nohup npm run preview > /opt/torrust-admin/logs/gui.log 2>&1 &
echo $! > /opt/torrust-admin/gui.pid
cd ..

echo "✅ All Torrust services started!"
`;

        fs.writeFileSync('/opt/torrust-admin/start-torrust.sh', startScript);
        executeCommand('chmod +x /opt/torrust-admin/start-torrust.sh && mkdir -p /opt/torrust-admin/logs && cd /opt/torrust-admin && ./start-torrust.sh', (result) => {
            res.json(result);
        });
    } else {
        // Start specific service
        let startCommand = '';
        switch(service) {
            case 'tracker':
                startCommand = 'cd /opt/torrust-admin/torrust-services/tracker && nohup ./target/release/torrust-tracker > /opt/torrust-admin/logs/tracker.log 2>&1 &';
                break;
            case 'index':
                startCommand = 'cd /opt/torrust-admin/torrust-services/index && nohup ./target/release/torrust-index > /opt/torrust-admin/logs/index.log 2>&1 &';
                break;
            case 'gui':
                startCommand = 'cd /opt/torrust-admin/torrust-services/gui && nohup npm run preview > /opt/torrust-admin/logs/gui.log 2>&1 &';
                break;
        }
        
        executeCommand(`mkdir -p /opt/torrust-admin/logs && ${startCommand}`, (result) => {
            res.json(result);
        });
    }
});

app.post('/api/torrust/stop', (req, res) => {
    const { service } = req.body;
    
    if (service === 'all') {
        // Stop all Torrust services
        executeCommand('cd /opt/torrust-admin && /usr/local/bin/docker-compose -f torrust-docker-compose.yml down', (result) => {
            res.json(result);
        });
    } else {
        // Stop specific service
        executeCommand(`cd /opt/torrust-admin && /usr/local/bin/docker-compose -f torrust-docker-compose.yml stop ${service}`, (result) => {
            res.json(result);
        });
    }
});

app.get('/api/torrust/logs/:service', (req, res) => {
    const { service } = req.params;
    
    executeCommand(`cd /opt/torrust-admin && /usr/local/bin/docker-compose -f torrust-docker-compose.yml logs --tail=100 ${service}`, (result) => {
        res.json(result);
    });
});

app.get('/api/torrust/status', (req, res) => {
    executeCommand('cd /opt/torrust-admin && /usr/local/bin/docker-compose -f torrust-docker-compose.yml ps', (result) => {
        res.json(result);
    });
});

// Add missing logs endpoint for individual services
app.get('/api/services/:name/logs', (req, res) => {
    const { name } = req.params;
    
    // Map service names to our configuration
    const serviceMap = {
        'torrust-tracker': 'tracker',
        'torrust-index': 'index', 
        'torrust-gui': 'gui'
    };
    
    const serviceKey = serviceMap[name] || name;
    
    // Check if the service exists in our configuration
    if (!TORRUST_SERVICES[serviceKey]) {
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