#!/bin/bash

echo "🧹 Cleaning up existing Kubernetes and Docker installation..."

# Stop and disable services
sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl disable kubelet 2>/dev/null || true
sudo systemctl disable docker 2>/dev/null || true

# Reset kubeadm if it exists
if command -v kubeadm &> /dev/null; then
    echo "🔄 Resetting kubeadm..."
    sudo kubeadm reset -f 2>/dev/null || true
fi

# Remove Kubernetes packages
echo "📦 Removing Kubernetes packages..."
sudo apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
sudo apt-get remove -y kubelet kubeadm kubectl kubernetes-cni 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# Remove Docker
echo "🐳 Removing Docker..."
sudo apt-get remove -y docker.io docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# Clean up Docker files and directories
echo "🗑️ Cleaning up Docker files..."
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/containerd

# Clean up Kubernetes files
echo "🗑️ Cleaning up Kubernetes files..."
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/etcd
sudo rm -rf ~/.kube
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
sudo rm -rf /var/lib/cni

# Clean up network interfaces
echo "🌐 Cleaning up network interfaces..."
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete docker0 2>/dev/null || true

# Clean up iptables rules
echo "🔥 Cleaning up iptables rules..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# Remove repository keys and sources
echo "🔑 Cleaning up repository keys..."
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/sources.list.d/docker.list

# Clean up systemd
echo "🔧 Cleaning up systemd..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Clean up helm if exists
if command -v helm &> /dev/null; then
    echo "⚓ Removing Helm..."
    sudo rm -f /usr/local/bin/helm
fi

# Clean up sysctl settings
echo "🔧 Cleaning up sysctl settings..."
sudo sed -i '/vm.overcommit_memory=1/d' /etc/sysctl.conf
sudo sed -i '/vm.panic_on_oom=0/d' /etc/sysctl.conf
sudo sed -i '/vm.oom_kill_allocating_task=1/d' /etc/sysctl.conf
sudo sed -i '/net.bridge.bridge-nf-call/d' /etc/sysctl.conf

# Clean up modules
echo "🔧 Cleaning up kernel modules..."
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf

# Re-enable swap if it was disabled
echo "💾 Re-enabling swap..."
sudo sed -i '/^#.*swap/s/^#//' /etc/fstab
sudo swapon -a 2>/dev/null || true

# Clean up any remaining processes
echo "🔄 Cleaning up remaining processes..."
sudo pkill -f kubelet 2>/dev/null || true
sudo pkill -f dockerd 2>/dev/null || true
sudo pkill -f containerd 2>/dev/null || true

# Update package lists
echo "📋 Updating package lists..."
sudo apt-get update -y

# Clean up log files
echo "📝 Cleaning up log files..."
sudo journalctl --vacuum-time=1d 2>/dev/null || true

echo "✅ Cleanup complete!"
echo "🔄 Please reboot the system before running ec2-setup.sh"
echo "💡 Run: sudo reboot"
