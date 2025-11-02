#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > >(tee -a /var/log/user-data.log)
exec 2>&1
echo "=== Starting backend deployment at $(date) ==="

# Install Docker
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu || true

sleep 3

# Pull exact immutable image (ingevuld door Terraform via templatefile)
BACKEND_IMAGE="${backend_image}"

echo "Pulling backend image: $BACKEND_IMAGE"
docker pull "$BACKEND_IMAGE"

# (Idempotent) verwijder oude containers als die er toch zijn
docker rm -f backend mongodb >/dev/null 2>&1 || true

echo "Starting MongoDB..."
docker run -d --name mongodb --restart=unless-stopped -p 27017:27017 mongo:5

sleep 8

echo "Starting backend..."
docker run -d --name backend --restart=unless-stopped \
  --link mongodb:mongodb \
  -p 8080:3000 \
  -e PORT=3000 \
  -e DBURL="mongodb://mongodb:27017/todoapp" \
  "$BACKEND_IMAGE"

echo "=== Backend deployment finished at $(date) ==="
