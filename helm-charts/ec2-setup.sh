#!/bin/bash

echo "🚀 Setting up EC2 Ubuntu instance for Kubernetes deployment..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install minikube
echo "Installing minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install Helm
echo "Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install -y helm

# Install Git (if not present)
echo "Installing Git..."
sudo apt install -y git

# Install Node.js and npm (for building UI)
echo "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Start Docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Start minikube
echo "Starting minikube..."
minikube start --driver=docker --memory=4096 --cpus=2

# Enable minikube addons
echo "Enabling minikube addons..."
minikube addons enable ingress

echo "✅ EC2 setup completed!"
echo ""
echo "📋 Installed versions:"
echo "  Docker: $(docker --version)"
echo "  kubectl: $(kubectl version --client --short)"
echo "  minikube: $(minikube version --short)"
echo "  Helm: $(helm version --short)"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo ""
echo "🔧 Next steps:"
echo "  1. Log out and log back in to apply Docker group changes"
echo "  2. Run ./ec2-deploy.sh to deploy your application"
echo ""
echo "💡 Minikube status:"
minikube status
