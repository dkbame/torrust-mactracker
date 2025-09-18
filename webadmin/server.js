const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Simple API routes
app.get('/api/status', (req, res) => {
    res.json({ 
        status: 'running', 
        message: 'Torrust Web Admin is running!',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/services', (req, res) => {
    res.json({
        success: true,
        data: [
            {
                name: 'torrust-tracker',
                status: 'stopped',
                image: 'torrust/torrust-tracker:latest',
                ports: ['6969/udp', '7070', '1212']
            },
            {
                name: 'torrust-index',
                status: 'stopped', 
                image: 'torrust/torrust-index:latest',
                ports: ['3001', '3002']
            },
            {
                name: 'torrust-gui',
                status: 'stopped',
                image: 'torrust/torrust-index-gui:latest', 
                ports: ['3000']
            }
        ]
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