#!/bin/bash

echo "🔧 Fixing containerd metadata database issue..."

# Stop all container services
sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true

# Clean up containerd completely
echo "🧹 Cleaning up containerd..."
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/containerd
sudo rm -rf /run/containerd
sudo rm -rf /opt/containerd

# Remove and reinstall containerd
echo "📦 Reinstalling containerd..."
sudo apt-get remove -y containerd containerd.io 2>/dev/null || true
sudo apt-get update
sudo apt-get install -y containerd

# Configure containerd properly
echo "⚙️ Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup driver in containerd
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Start containerd first
sudo systemctl enable containerd
sudo systemctl start containerd

# Wait for containerd to be ready
echo "⏳ Waiting for containerd to initialize..."
sleep 10

# Check if containerd is running
if sudo systemctl is-active --quiet containerd; then
    echo "✅ containerd is running"
else
    echo "❌ containerd failed to start"
    sudo systemctl status containerd
    exit 1
fi

# Configure Docker to use containerd properly
echo "🐳 Configuring Docker to work with containerd..."
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

# Start Docker
sudo systemctl daemon-reload
sudo systemctl start docker

# Check if Docker is running
if sudo systemctl is-active --quiet docker; then
    echo "✅ Docker is running"
else
    echo "❌ Docker failed to start"
    sudo systemctl status docker
    exit 1
fi

# Test container runtime
echo "🧪 Testing container runtime..."
sudo docker run --rm hello-world

if [ $? -eq 0 ]; then
    echo "✅ Container runtime is working properly"
else
    echo "❌ Container runtime test failed"
    exit 1
fi

echo "✅ containerd and Docker are now properly configured!"
echo "🚀 You can now run kubeadm init again"
