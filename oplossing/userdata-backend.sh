#!/bin/bash
set -euo pipefail

# Waardes uit Terraform (literal strings)
DOCKER_NS_RAW="${DOCKER_NS}"
BACKEND_DIGEST="${BACKEND_DIGEST}"
MONGO_REF="${MONGO_REF}"
DBURL="${DBURL}"

# Forceer lowercase namespace
DOCKER_NS="$(echo "$${DOCKER_NS_RAW}" | tr '[:upper:]' '[:lower:]')"

apt-get update -y
apt-get install -y docker.io curl
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

docker network create todo-net || true

if [ -n "$${BACKEND_DIGEST}" ]; then
  BACKEND_REF="docker.io/$${DOCKER_NS}/todo-backend@$${BACKEND_DIGEST}"
else
  BACKEND_REF="docker.io/$${DOCKER_NS}/todo-backend:latest"
fi

docker pull "$${MONGO_REF}"
docker pull "$${BACKEND_REF}"

docker rm -f mongodb 2>/dev/null || true
docker run -d --name mongodb --network todo-net \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  --restart unless-stopped \
  --health-cmd='mongo --quiet --eval "db.runCommand({ ping: 1 })" || exit 1' \
  --health-interval=20s --health-timeout=5s --health-retries=6 \
  "$${MONGO_REF}"

echo "Wachten tot MongoDB healthy is..."
for i in $(seq 1 30); do
  if docker inspect --format='{{json .State.Health.Status}}' mongodb 2>/dev/null | grep -q healthy; then
    echo "MongoDB is healthy."
    break
  fi
  sleep 2
done

docker rm -f todo-backend 2>/dev/null || true
docker run -d --name todo-backend --network todo-net \
  -p 3000:3000 \
  -e DBURL="$${DBURL}" \
  --restart unless-stopped \
  "$${BACKEND_REF}"
