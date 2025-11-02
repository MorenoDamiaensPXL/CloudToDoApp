#!/bin/bash
set -euo pipefail

# -------- Config van Terraform (templatefile) --------
DOCKER_NS_RAW="$${DOCKER_NS:-}"
BACKEND_DIGEST="$${BACKEND_DIGEST:-}"
MONGO_REF="$${MONGO_REF:-docker.io/library/mongo:7.0.14}"
DBURL="$${DBURL:-mongodb://root:password@mongodb:27017/sampledb?authSource=admin}"

# Forceer lowercase namespace
DOCKER_NS="$(echo "$${DOCKER_NS_RAW}" | tr '[:upper:]' '[:lower:]')"

# -------- Basis packages + Docker --------
apt-get update -y
apt-get install -y docker.io curl
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

# Netwerk voor app
docker network create todo-net || true

# Pull exact images (immutabel via digest waar mogelijk)
if [ -n "$${BACKEND_DIGEST}" ]; then
  BACKEND_REF="docker.io/$${DOCKER_NS}/todo-backend@$${BACKEND_DIGEST}"
else
  BACKEND_REF="docker.io/$${DOCKER_NS}/todo-backend:latest"
fi

docker pull "$${MONGO_REF}"
docker pull "$${BACKEND_REF}"

# MongoDB (met healthcheck)
docker rm -f mongodb 2>/dev/null || true
docker run -d --name mongodb --network todo-net \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  --restart unless-stopped \
  --health-cmd='mongo --quiet --eval "db.runCommand({ ping: 1 })" || exit 1' \
  --health-interval=20s --health-timeout=5s --health-retries=6 \
  "$${MONGO_REF}"

# Wacht tot Mongo healthy is
echo "Wachten tot MongoDB healthy is..."
for i in $(seq 1 30); do
  if docker inspect --format='{{json .State.Health.Status}}' mongodb 2>/dev/null | grep -q healthy; then
    echo "MongoDB is healthy."
    break
  fi
  sleep 2
done

# Backend
docker rm -f todo-backend 2>/dev/null || true
docker run -d --name todo-backend --network todo-net \
  -p 3000:3000 \
  -e DBURL="$${DBURL}" \
  --restart unless-stopped \
  "$${BACKEND_REF}"
