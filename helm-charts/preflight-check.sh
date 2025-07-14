#!/bin/bash

echo "🔍 Pre-flight system check for t3.medium..."

# Check system resources
echo "📊 System Resources:"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "CPU: $(nproc) cores"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') available"

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo "❌ User needs sudo privileges without password prompt"
    echo "💡 Run: sudo visudo and add: $USER ALL=(ALL) NOPASSWD:ALL"
    exit 1
fi

# Check memory (should be at least 3GB total)
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [ "$TOTAL_MEM" -lt 3000 ]; then
    echo "⚠️ Warning: Low memory detected ($TOTAL_MEM MB). Minimum 3GB recommended."
fi

# Check disk space (should be at least 6GB free)
FREE_DISK=$(df / | tail -1 | awk '{print $4}')
FREE_DISK_GB=$((FREE_DISK / 1024 / 1024))
if [ "$FREE_DISK_GB" -lt 6 ]; then
    echo "⚠️ Warning: Low disk space ($FREE_DISK_GB GB free). Minimum 6GB recommended."
fi

# Check for existing services
echo "🔍 Checking for existing services..."
if systemctl is-active --quiet kubelet; then
    echo "❌ Kubelet is already running. Run cleanup-ec2.sh first."
    exit 1
fi

if systemctl is-active --quiet docker; then
    echo "⚠️ Docker is already running. Will be reconfigured during setup."
fi

# Check network connectivity
echo "🌐 Testing network connectivity..."
if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "❌ No internet connectivity. Please check network settings."
    exit 1
fi

# Check if ports are available
echo "🔌 Checking required ports..."
PORTS=(6443 10250 10251 10252 2379 2380 30300)
for port in "${PORTS[@]}"; do
    if netstat -tuln | grep -q ":$port "; then
        echo "⚠️ Port $port is already in use"
    fi
done

# Check kernel version
KERNEL_VERSION=$(uname -r)
echo "🔧 Kernel version: $KERNEL_VERSION"

# Check if br_netfilter module can be loaded
if ! modprobe br_netfilter 2>/dev/null; then
    echo "⚠️ Warning: br_netfilter module not available"
fi

echo "✅ Pre-flight check completed"
echo "💡 If all checks passed, you can now run: ./ec2-setup.sh"
