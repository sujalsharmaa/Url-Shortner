#!/bin/bash

# Log cleanup script
LOG_DIR="/var/log"
RETENTION_DAYS=30

echo "Cleaning up log files older than $RETENTION_DAYS days in $LOG_DIR..."

find "$LOG_DIR" -type f -name "*.log" -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "Log cleanup complete."

# 0 2 * * * /path/to/cleanup_logs.sh