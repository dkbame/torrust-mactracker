const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const Docker = require('dockerode');
const WebSocket = require('ws');
const cron = require('node-cron');

const app = express();
const PORT = process.env.PORT || 8080;

// Docker client
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// WebSocket server for real-time updates
const wss = new WebSocket.Server({ port: 8081 });

// Store connected clients
const clients = new Set();

wss.on('connection', (ws) => {
  clients.add(ws);
  console.log('WebSocket client connected');
  
  ws.on('close', () => {
    clients.delete(ws);
    console.log('WebSocket client disconnected');
  });
});

// Broadcast to all connected clients
function broadcast(data) {
  const message = JSON.stringify(data);
  clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// Get container status
async function getContainerStatus() {
  try {
    const containers = await docker.listContainers({ all: true });
    const torrustContainers = containers.filter(container => 
      container.Names.some(name => name.includes('torrust'))
    );
    
    return torrustContainers.map(container => ({
      id: container.Id,
      name: container.Names[0].replace('/', ''),
      status: container.State,
      image: container.Image,
      ports: container.Ports,
      created: container.Created
    }));
  } catch (error) {
    console.error('Error getting container status:', error);
    return [];
  }
}

// Get container logs
async function getContainerLogs(containerName, lines = 100) {
  try {
    const container = docker.getContainer(containerName);
    const logs = await container.logs({
      stdout: true,
      stderr: true,
      tail: lines,
      timestamps: true
    });
    return logs.toString();
  } catch (error) {
    console.error('Error getting container logs:', error);
    return 'Error retrieving logs';
  }
}

// API Routes

// Get all services status
app.get('/api/services', async (req, res) => {
  try {
    const services = await getContainerStatus();
    res.json({ success: true, data: services });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get specific service logs
app.get('/api/services/:name/logs', async (req, res) => {
  try {
    const { name } = req.params;
    const logs = await getContainerLogs(name);
    res.json({ success: true, data: logs });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Start service
app.post('/api/services/:name/start', async (req, res) => {
  try {
    const { name } = req.params;
    const container = docker.getContainer(name);
    await container.start();
    res.json({ success: true, message: `Service ${name} started` });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Stop service
app.post('/api/services/:name/stop', async (req, res) => {
  try {
    const { name } = req.params;
    const container = docker.getContainer(name);
    await container.stop();
    res.json({ success: true, message: `Service ${name} stopped` });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Restart service
app.post('/api/services/:name/restart', async (req, res) => {
  try {
    const { name } = req.params;
    const container = docker.getContainer(name);
    await container.restart();
    res.json({ success: true, message: `Service ${name} restarted` });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get system info
app.get('/api/system', async (req, res) => {
  try {
    const info = await docker.info();
    res.json({ success: true, data: info });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Serve the main dashboard
app.get('/', (req, res) => {
  res.sendFile(__dirname + '/public/index.html');
});

// Periodic status updates
cron.schedule('*/5 * * * * *', async () => {
  try {
    const services = await getContainerStatus();
    broadcast({ type: 'status_update', data: services });
  } catch (error) {
    console.error('Error in periodic status update:', error);
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Torrust Web Admin running on port ${PORT}`);
  console.log(`📊 WebSocket server running on port 8081`);
});
