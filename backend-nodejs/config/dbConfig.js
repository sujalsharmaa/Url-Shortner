// config/dbConfig.js
require('dotenv').config();
const { Pool } = require('pg');

// Configure the PostgreSQL connection pool
const User = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    ssl: {
        rejectUnauthorized: false, // Set to true if you have a trusted SSL certificate
    },
});

// Test the connection
User.connect()
    .then((client) => {
        console.log('Connected to RDS PostgreSQL database!');
        client.release(); // release the client back to the pool
    })
    .catch((error) => console.error('Unable to connect to the database:', error));

module.exports = User;
