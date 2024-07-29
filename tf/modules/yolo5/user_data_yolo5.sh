#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Update package index
sudo apt update

# Install necessary dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository to APT sources (Auto-confirm with echo)
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Update package index again
sudo apt update

# Install Docker CE without prompts
sudo apt-get install -y docker-ce

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to the docker group
sudo usermod -aG docker $USER

sudo docker login -u loaykewan -p loayk57900
sudo docker pull loaykewan/yolo5_images_region.eu-west-3:1
sudo docker run --name my_yolo5_test loaykewan/yolo5_images_region.eu-west-3:1

