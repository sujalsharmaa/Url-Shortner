#!/bin/bash

# System update script
echo "Updating package lists..."
sudo apt update

echo "Upgrading packages..."
sudo apt upgrade -y

echo "Cleaning up unused packages..."
sudo apt autoremove -y
sudo apt autoclean

echo "System update complete."

# 0 4 1 * * /path/to/update_system.sh
