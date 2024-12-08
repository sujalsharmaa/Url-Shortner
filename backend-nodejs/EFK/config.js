const logger = require('./logger');

app.get('/', (req, res) => {
  logger.info({ message: 'Home route accessed', timestamp: new Date() });
  res.send('Hello, EFK!');
});
