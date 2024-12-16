#!/bin/bash

# Update and install essential tools
echo "Updating system and installing prerequisites..."
apt-get update -y && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release unzip

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Add user to Docker group
echo "Adding user to Docker group..."
usermod -aG docker ubuntu

# Clean up unused packages
apt-get autoremove -y
apt-get clean

# Verify Docker installation
echo "Docker version:"
docker --version || { echo "Docker installation failed!"; exit 1; }

# Clone repository
REPO_URL="https://github.com/sujalsharmaa/Url-Shortner.git"
REPO_DIR="Url-Shortner"

echo "Cloning repository..."
git clone "$REPO_URL" || { echo "Failed to clone repository!"; exit 1; }

# Navigate to the backend-nodejs directory
cd "$REPO_DIR/kubernetes-manifests/prometheus" || { echo "Failed to navigate to backend-nodejs!"; exit 1; }

# Build Docker image
docker run -d -p 6379:6379 redis
docker compose up -d --build

# Get the container ID of the Grafana container
CONTAINER_ID=$(docker ps | grep "grafana" | awk '{print $1}')

# Check if a container ID was found
if [ -z "$CONTAINER_ID" ]; then
  echo "Grafana container not found. Please ensure Grafana is running."
  exit 1
fi

# Append the new SMTP configuration to grafana.ini
docker exec -u 0 "$CONTAINER_ID" bash -c "cat >> /etc/grafana/grafana.ini <<EOF
[smtp]
enabled = true
host = smtp.gmail.com:587
user = techsharma53@gmail.com
password = csvdmvyncmjovwwx
skip_verify = true
from_address = techsharma53@gmail.com
from_name = sujalsharma
EOF"

# Restart the Grafana container
docker restart "$CONTAINER_ID"

echo "Grafana configuration updated and container restarted successfully."
