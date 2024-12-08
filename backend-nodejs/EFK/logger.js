const { createLogger, format, transports } = require('winston');
require('winston-fluentd').FluentTransport;

const logger = createLogger({
    level: 'info',
    format: format.combine(
        format.timestamp(),
        format.json()
    ),
    transports: [
        new transports.Console(), // Logs to console
        new transports.FluentTransport('myapp', {
            host: process.env.FLUENTD_HOST || 'localhost',
            port: process.env.FLUENTD_PORT || 24224,
        }),
    ],
});

module.exports = logger;
