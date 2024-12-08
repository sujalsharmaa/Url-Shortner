const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../config/dbConfig'); // Database connection pool
const redis = require('../cache/redisClient');
const winston = require('winston'); // For structured logging
require('dotenv').config();

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;

// Winston Logger setup
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'auth-service.log' }),
    ],
});

// Middleware for logging every request
router.use((req, res, next) => {
    logger.info({ method: req.method, url: req.url, timestamp: new Date() });
    next();
});

// Utility to handle errors
const handleError = (res, error, message, status = 500) => {
    logger.error({ message, error: error.message, stack: error.stack });
    res.status(status).json({ error: message });
};

// Route: Register a new user
router.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Check if username already exists
        const existingUser = await User.query('SELECT * FROM users WHERE username = $1', [username]);
        if (existingUser.rows.length > 0) {
            return res.status(409).json({ error: 'Username already exists' }); // HTTP 409 Conflict
        }

        // Hash the password and insert the new user into the database
        const hashedPassword = await bcrypt.hash(password, 10);
        const result = await User.query(
            'INSERT INTO users (username, password) VALUES ($1, $2) RETURNING id',
            [username, hashedPassword]
        );

        // Respond with success
        const newUserId = result.rows[0].id;
        res.status(201).json({ message: 'User registered', userId: newUserId });
    } catch (error) {
        // Handle database constraint violations
        if (error.code === '23505') {
            return res.status(409).json({ error: 'Username already exists' });
        }
        handleError(res, error, 'Error registering user');
    }
});

// Route: Login and generate JWT token
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Fetch user from the database
        const result = await User.query('SELECT * FROM users WHERE username = $1', [username]);
        const user = result.rows[0];

        // Verify user credentials
        if (!user || !(await bcrypt.compare(password, user.password))) {
            return res.status(401).json({ error: 'Invalid credentials' }); // HTTP 401 Unauthorized
        }

        // Generate JWT token
        const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '1h' });

        // Cache session in Redis
        await redis.set(`session:${user.id}`, token, 'EX', 3600);

        res.json({ message: 'Login successful', token });
    } catch (error) {
        handleError(res, error, 'Error logging in');
    }
});

// Middleware: Authenticate user with JWT and Redis session
const authenticate = async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token missing' });

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        const cachedToken = await redis.get(`session:${decoded.userId}`);

        if (cachedToken !== token) {
            return res.status(401).json({ error: 'Invalid session' });
        }

        req.user = decoded;
        next();
    } catch (error) {
        handleError(res, error, 'Authentication failed', 401);
    }
};

// Route: Create a short URL
router.post('/url', authenticate, async (req, res) => {
    const { url } = req.body;
    const userId = req.user.userId;

    try {
        // Request to URL shortener service
        const response = await fetch(`${process.env.URL_SHORTNER_LINK}/shorten`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url, user_id: userId }),
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Error from URL Shortener service');

        // Update Redis with new URLs
        const updatedUrls = await User.query(
            'SELECT original_url, short_url FROM urls WHERE user_id = $1',
            [userId]
        );
        await redis.set(`urls:${userId}`, JSON.stringify(updatedUrls.rows), 'EX', 3600);

        res.status(201).json({ short_url: data.short_url, original_url: url });
    } catch (error) {
        handleError(res, error, 'Failed to shorten URL');
    }
});

// Route: Get all URLs for a user
router.get('/getAllUrls', authenticate, async (req, res) => {
    const userId = req.user.userId;

    try {
        // Check Redis cache for user's URLs
        const cachedUrls = await redis.get(`urls:${userId}`);
        if (cachedUrls) {
            logger.info({ message: 'Cache hit for user URLs', userId });
            return res.status(200).json(JSON.parse(cachedUrls));
        }

        // Fetch URLs from database if not cached
        const result = await User.query(
            'SELECT original_url, short_url FROM urls WHERE user_id = $1',
            [userId]
        );
        const response = result.rows;

        // Cache the result in Redis
        await redis.set(`urls:${userId}`, JSON.stringify(response), 'EX', 3600);
        logger.info({ message: 'Cache updated for user URLs', userId });

        res.status(200).json(response);
    } catch (error) {
        handleError(res, error, 'Error fetching URLs');
    }
});

module.exports = { router, authenticate };
