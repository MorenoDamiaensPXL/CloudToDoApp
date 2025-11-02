#!/bin/bash
set -e

# Install Docker
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

# Run MongoDB
sudo docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  mongo:7

# Wait for MongoDB to initialize
sleep 10

# Pull latest backend
sudo docker pull evrendem/todo-backend:latest

# Run backend and connect to MongoDB
sudo docker run -d \
  --name todo-backend \
  --link mongodb \
  -p 3000:3000 \
  -e DBURL="mongodb://root:password@mongodb:27017/sampledb?authSource=admin" \
  dynamoz/todo-backend:latest
