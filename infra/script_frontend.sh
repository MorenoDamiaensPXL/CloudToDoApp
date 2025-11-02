#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

exec > >(tee -a /var/log/user-data.log)
exec 2>&1
echo "=== Starting frontend deployment at $(date) ==="

# Install Docker
apt-get update -y
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu || true

# Backend URL van de backend instance (ingevuld door Terraform)
BACKEND_URL="http://${backend_ip}:8080"

# Exact immutable image (ingevuld door Terraform via templatefile)
FRONTEND_IMAGE="${frontend_image}"

echo "Pulling frontend image: $FRONTEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

# (Idempotent) remove oude container als die er is
docker rm -f frontend >/dev/null 2>&1 || true

echo "Starting frontend (API_URL=$BACKEND_URL)..."
docker run -d --name frontend --restart=unless-stopped \
  -p 80:80 \
  -e API_URL="$BACKEND_URL" \
  "$FRONTEND_IMAGE"

echo "Frontend is running on port 80"
echo "Frontend configured to connect to: $BACKEND_URL"
echo "=== Frontend deployment completed at $(date) ==="
