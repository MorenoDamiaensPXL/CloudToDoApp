#!/bin/bash
set -e
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

sudo docker pull evrendem/todo-frontend:latest
sudo docker run -d -p 80:80 --name todo-frontend evrendem/todo-frontend:latest
