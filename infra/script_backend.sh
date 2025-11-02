#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > >(tee -a /var/log/user-data.log)
exec 2>&1
echo "=== Starting backend deployment at $(date) ==="

# Install Docker and Git
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu

sleep 5

# Start MongoDB container
echo "Starting MongoDB..."
docker run -d --name mongodb --restart=unless-stopped -p 27017:27017 mongo:5

sleep 10

# Build and run backend
docker pull 12301302/cloud2_backend:latest
docker run -d --name backend --restart=unless-stopped --link mongodb:mongodb -p 8080:3000 -e PORT=3000 -e DBURL="mongodb://mongodb:27017/todoapp" 12301302/cloud2_backend:latest