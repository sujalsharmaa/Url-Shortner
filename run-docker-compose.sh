#!/bin/bash

# Fetch the public IP address of the EC2 instance using the metadata service
HOST_IP=$(curl ifconfig.me)
echo ${HOST_IP}
# Check if the IP was successfully fetched
if [ -z "$HOST_IP" ]; then
  echo "Failed to fetch public IP. Ensure the script is running on an EC2 instance with a public IP."
  exit 1
fi

# Export the IP address as an environment variable
export HOST_IP

# Run docker-compose with the updated environment
sudo HOST_IP=$HOST_IP docker compose up --build
