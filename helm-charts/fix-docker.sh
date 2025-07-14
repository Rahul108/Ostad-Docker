#!/bin/bash

echo "🔧 Quick Docker fix for runtime configuration issue..."

# Stop Docker service
sudo systemctl stop docker

# Remove problematic daemon.json
sudo rm -f /etc/docker/daemon.json

# Create minimal working daemon.json
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m"
  },
  "storage-driver": "overlay2"
}
EOF

# Reload systemd and restart Docker
sudo systemctl daemon-reload
sudo systemctl start docker

# Check if Docker is running
if sudo systemctl is-active --quiet docker; then
    echo "✅ Docker is now running successfully!"
    sudo docker --version
else
    echo "❌ Docker still not working. Trying without daemon.json..."
    sudo rm -f /etc/docker/daemon.json
    sudo systemctl restart docker
    
    if sudo systemctl is-active --quiet docker; then
        echo "✅ Docker is now running without daemon.json!"
        sudo docker --version
    else
        echo "❌ Docker still failing. Check the logs:"
        sudo journalctl -u docker --no-pager --lines=20
    fi
fi
