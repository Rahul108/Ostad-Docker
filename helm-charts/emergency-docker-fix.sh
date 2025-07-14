#!/bin/bash

echo "🔧 Emergency Docker fix - removing problematic overlay2 option..."

# Stop Docker
sudo systemctl stop docker

# Create clean daemon.json without the problematic overlay2 option
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

# Restart Docker
sudo systemctl daemon-reload
sudo systemctl start docker

# Check status
if sudo systemctl is-active --quiet docker; then
    echo "✅ Docker is now running!"
    sudo docker version
else
    echo "❌ Still having issues. Trying without daemon.json..."
    sudo rm -f /etc/docker/daemon.json
    sudo systemctl restart docker
    if sudo systemctl is-active --quiet docker; then
        echo "✅ Docker working without daemon.json"
    else
        echo "❌ Docker still failing"
        sudo systemctl status docker
    fi
fi
