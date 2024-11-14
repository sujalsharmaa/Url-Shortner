const express = require('express');
const { router: authRoutes } = require('./routes/authRoutes');
const { router: metricsRouter, httpRequestCounter } = require('./metrics/prometheusMetrics');
const createTable = require('./createTable.js')
const User = require('./config/dbConfig.js')
const cors = require("cors")

const app = express();
app.use(express.json());
app.use(cors({
    origin: 'http://localhost:3001', // Allow only this origin
    credentials: true,               // Allow credentials (cookies, authorization headers, etc.)
}));
// Initialize database and models
app.get('/test', async (req, res) => {
    try {
        const result = await User.query('SELECT NOW()'); // Test query
        res.json({ message: 'Database connection is working!', time: result.rows[0] });
    } catch (error) {
        console.error('Error executing query:', error);
        res.status(500).json({ error: 'Database query failed' });
    }
});

// Increment Prometheus counter on each request
app.use((req, res, next) => {
    httpRequestCounter.inc();
    next();
});

// Define routes
app.use('/auth', authRoutes);
app.use('/metrics', metricsRouter);


app.get('/short/:url', async (req, res) => {
    const shortUrl = req.params.url;

    try {
        // Fetch the original URL from your URL shortener service or database
        const response = await fetch(`${process.env.URL_SHORTNER_LINK}/${shortUrl}`);
        if (!response.ok) {
            return res.status(404).json({ error: 'URL not found' });
        }

        // Assuming the response contains JSON data with the key `original_url`
        const data = await response.json();
        const originalUrl = data.original_url;

        // Redirect to the original URL, ensuring it starts with 'http' or 'https'
        if (!originalUrl.startsWith('http')) {
            return res.redirect(`http://${originalUrl}`);
        } else {
            return res.redirect(originalUrl);
        }
    } catch (error) {
        console.error('Error fetching URL:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});


// Start server
const PORT = process.env.PORT || 3000;
createTable()
app.listen(PORT, () => 
    console.log(`Server running on port ${PORT}`));
