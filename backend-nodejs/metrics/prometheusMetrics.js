const client = require('prom-client');
const express = require('express');
const router = express.Router();

// Create a registry and metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });
const httpRequestCounter = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
});

register.registerMetric(httpRequestCounter);

router.get('/', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

module.exports = { router, httpRequestCounter };
