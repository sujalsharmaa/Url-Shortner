#!/bin/bash

# Backup script
SOURCE_DIR="/home/user/data"
BACKUP_DIR="/home/user/backups"
DATE=$(date +"%Y%m%d")
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup of $SOURCE_DIR in $BACKUP_FILE..."

tar -czf "$BACKUP_FILE" "$SOURCE_DIR"

echo "Backup complete."

# 0 3 * * 0 /path/to/backup_data.sh
