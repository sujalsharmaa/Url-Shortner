const User = require('./config/dbConfig.js'); // Import the database connection pool

const createTable = async () => {
    try {
        // Create users table
        await User.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        // Create urls table
        await User.query(`
            CREATE TABLE IF NOT EXISTS urls (
                id SERIAL PRIMARY KEY,
                user_id INT REFERENCES users(id) ON DELETE CASCADE,
                original_url TEXT NOT NULL,
                short_url VARCHAR(50) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        console.log('Tables created successfully!');
    } catch (error) {
        console.error('Error creating tables:', error);
        throw error; // Re-throw to properly handle in the calling function
    }
};

module.exports = createTable;
