const express = require('express');
const cors = require('cors');
const { router: authRoutes } = require('./routes/authRoutes');
const { router: metricsRouter, httpRequestCounter } = require('./metrics/prometheusMetrics');
const createTable = require('./createTable.js');
const User = require('./config/dbConfig.js');
const redis = require('./cache/redisClient.js');
const winston = require('winston'); // Logging library

// Initialize Express app
const app = express();

// Middleware for parsing JSON requests
app.use(express.json());

// Configure CORS
const corsOptions = {
    origin: process.env.FRONTEND_URL, // Frontend's public IP and port
    credentials: true, // Allow cookies/credentials
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], // HTTP methods
    allowedHeaders: ['Content-Type', 'Authorization'], // Allow these headers
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // Handle preflight requests

// Winston Logger for structured logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'server.log' }),
    ],
});

// Middleware to log every incoming request
app.use((req, res, next) => {
    logger.info({
        method: req.method,
        url: req.url,
        timestamp: new Date(),
    });
    next();
});

// Middleware to increment Prometheus request counter
app.use((req, res, next) => {
    httpRequestCounter.inc();
    next();
});
app.get("/",(req,res)=>{
    res.send("hi node js backend works this is v4")
})

// Route: Test database and Redis connections
app.get('/test', async (req, res) => {
    try {
        // Test database query
        const result = await User.query('SELECT NOW()');

        // Test Redis connection
        await redis.set('PING', 'PONG');
        const response = await redis.get('PING');

        // Send success response
        res.json({
            message: 'Connections are working!',
            databaseTime: result.rows[0],
            redisResponse: response,
        });
    } catch (error) {
        logger.error({
            message: 'Error testing connections',
            error: error.message,
            stack: error.stack,
        });
        res.status(500).json({ error: 'Connection test failed' });
    }
});

// Route: Redirect short URLs to original URLs
app.get('/short/:url', async (req, res) => {
    const shortUrl = req.params.url;

    try {
        const response = await fetch(`${process.env.URL_SHORTNER_LINK}/${shortUrl}`);
        if (!response.ok) {
            return res.status(404).json({ error: 'URL not found' });
        }

        const data = await response.json();
        const originalUrl = data.original_url;

        // Ensure redirect works for URLs without "http" or "https"
        return originalUrl.startsWith('http')
            ? res.redirect(originalUrl)
            : res.redirect(`http://${originalUrl}`);
    } catch (error) {
        logger.error({
            message: 'Error fetching original URL',
            shortUrl,
            error: error.message,
            stack: error.stack,
        });
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// API routes
app.use('/auth', authRoutes); // Authentication routes
app.use('/metrics', metricsRouter); // Prometheus metrics route

// Error-handling middleware
app.use((err, req, res, next) => {
    logger.error({
        message: err.message,
        stack: err.stack,
        timestamp: new Date(),
    });
    res.status(500).send('Internal Server Error');
});

// Start the server
const PORT = process.env.PORT || 3000;

// Initialize database tables and start server
const startServer = async () => {
    try {
        console.log('Setting up database tables...');
        await createTable(); // Ensure tables are created before starting the server
        console.log('Database tables are ready!');

        // Start server after database is ready
        app.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
        });
    } catch (error) {
        console.error('Error starting server:', error);
        process.exit(1); // Exit with error code if setup fails
    }
};

startServer();
