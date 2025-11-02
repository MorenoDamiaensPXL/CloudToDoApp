#!/bin/bash
set -euo pipefail

# Waardes uit Terraform (worden hier als *literal strings* ingevuld)
DOCKER_NS_RAW="${DOCKER_NS}"
FRONTEND_DIGEST="${FRONTEND_DIGEST}"

# Forceer lowercase namespace in bash
DOCKER_NS="$(echo "$${DOCKER_NS_RAW}" | tr '[:upper:]' '[:lower:]')"

apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

if [ -n "$${FRONTEND_DIGEST}" ]; then
  FRONTEND_REF="docker.io/$${DOCKER_NS}/todo-frontend@$${FRONTEND_DIGEST}"
else
  FRONTEND_REF="docker.io/$${DOCKER_NS}/todo-frontend:latest"
fi

docker pull "$${FRONTEND_REF}"

docker rm -f todo-frontend 2>/dev/null || true
docker run -d --name todo-frontend \
  -p 80:80 \
  --restart unless-stopped \
  "$${FRONTEND_REF}"
