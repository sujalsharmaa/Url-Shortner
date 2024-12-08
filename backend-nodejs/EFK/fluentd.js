const FluentTransport = require('winston-fluentd').FluentTransport;

const logger = createLogger({
  level: 'info',
  format: format.json(),
  transports: [
    new FluentTransport('fluentd', {
      host: 'localhost', // Fluentd host
      port: 24224,       // Fluentd port
      timeout: 3.0,
      requireAckResponse: true
    })
  ]
});
