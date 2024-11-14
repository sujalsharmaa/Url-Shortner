const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../config/dbConfig'); // Import the database connection pool
const redis = require('../cache/redisClient');
require('dotenv').config();

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;

// Register a new user
router.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        console.log(username,password)
        const hashedPassword = await bcrypt.hash(password, 10);

        // Insert the new user into the database
        const result = await User.query(
            'INSERT INTO users (username, password) VALUES ($1, $2) RETURNING id',
            [username, hashedPassword]
        );

        const newUserId = result.rows[0].id;
        res.status(201).json({ message: 'User registered', userId: newUserId });
    } catch (error) {
        console.error('Error registering user:', error);
        res.status(500).json({ error: 'Error registering user' });
    }
});

// Login and generate JWT token
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Fetch the user from the database by username
        const result = await User.query('SELECT * FROM users WHERE username = $1', [username]);
        const user = result.rows[0];

        if (!user || !(await bcrypt.compare(password, user.password))) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate JWT token
        const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '1h' });

        // Cache session in Redis
        await redis.set(`session:${user.id}`, token, 'EX', 3600);

        res.json({ message: 'Login successful', token });
    } catch (error) {
        console.error('Error logging in:', error);
        res.status(500).json({ error: 'Error logging in' });
    }
});

// Middleware to verify JWT and session
const authenticate = async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token missing' });
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      const cachedToken = await redis.get(`session:${decoded.userId}`);
      if (cachedToken !== token) return res.status(401).json({ error: 'Invalid session' });
      req.user = decoded;
      next();
    } catch (error) {
      console.error('Authentication failed:', error);
      res.status(401).json({ error: 'Authentication failed' });
    }
  };
  

  router.post('/url', authenticate, async (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token missing' });

    const decoded = jwt.verify(token, JWT_SECRET);
    const user_id = decoded.userId;
    const { url } = req.body;

    try {
        // Make a request to the URL shortener service
        const response = await fetch(`${process.env.URL_SHORTNER_LINK}/shorten`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url, user_id }),
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Error from URL Shortener service');

        // After successfully creating the new URL, query the database for the updated list
        const result = await User.query(
            'SELECT original_url, short_url FROM urls WHERE user_id = $1',
            [user_id]
        );
        const updatedUrls = result.rows;

        // Update Redis cache with the new list of URLs
        await redis.set(`urls:${user_id}`, JSON.stringify(updatedUrls), 'EX', 3600);

        res.status(201).json({ short_url: data.short_url, original_url: url });
    } catch (error) {
        console.error('Error in URL Shortener request:', error);
        res.status(500).json({ error: 'Failed to shorten URL' });
    }
});


router.get('/getAllUrls', authenticate, async (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Token missing' });

    const decoded = jwt.verify(token, JWT_SECRET);
    const user_id = decoded.userId;

    try {
        // Check if data is already cached in Redis
        const cachedUrls = await redis.get(`urls:${user_id}`);
        if (cachedUrls) {
            console.log('Cache hit');
            // Parse and send the cached data
            return res.status(200).json(JSON.parse(cachedUrls));
        }

        // If not found in cache, query the database
        console.log('Cache miss');
        const result = await User.query(
            'SELECT original_url, short_url FROM urls WHERE user_id = $1',
            [user_id]
        );
        const response = result.rows;

        // Store the result in Redis cache with an expiration time (e.g., 1 hour)
        await redis.set(`urls:${user_id}`, JSON.stringify(response), 'EX', 3600);

        res.status(200).json(response);
    } catch (error) {
        console.error('Error fetching URLs:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});



module.exports = { router, authenticate };
