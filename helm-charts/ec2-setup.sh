#!/bin/bash

echo "🚀 Setting up Kubernetes and monitoring for t3.medium..."

# Check if script is run as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please do not run this script as root. Run as regular user with sudo privileges."
    exit 1
fi

# Check for existing installations
echo "🔍 Checking for existing installations..."
if systemctl is-active --quiet kubelet; then
    echo "⚠️ Kubernetes is already running. Please run cleanup-ec2.sh first."
    exit 1
fi

if systemctl is-active --quiet docker; then
    echo "⚠️ Docker is already running. Attempting to stop and reconfigure..."
    sudo systemctl stop docker
    sudo systemctl disable docker
fi

# Clean up any existing Docker installation
echo "🧹 Cleaning up existing Docker installation..."
sudo apt-get remove -y docker.io docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/containerd

# System optimizations for t3.medium (4GB RAM)
sudo sysctl vm.overcommit_memory=1
sudo sysctl vm.panic_on_oom=0
sudo sysctl vm.oom_kill_allocating_task=1
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.panic_on_oom=0' | sudo tee -a /etc/sysctl.conf
echo 'vm.oom_kill_allocating_task=1' | sudo tee -a /etc/sysctl.conf

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Install Docker with better error handling
echo "🐳 Installing Docker..."
sudo apt-get install -y docker.io

# Check if Docker installation was successful
if ! command -v docker &> /dev/null; then
    echo "❌ Docker installation failed. Trying alternative method..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

# Configure Docker daemon before starting
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "runc"
    }
  },
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
EOF

# Start Docker with error handling
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker is running
if ! sudo systemctl is-active --quiet docker; then
    echo "❌ Docker failed to start. Checking logs..."
    sudo journalctl -u docker --no-pager --lines=10
    echo "🔄 Attempting to restart Docker..."
    sudo systemctl restart docker
    sleep 5
    if ! sudo systemctl is-active --quiet docker; then
        echo "❌ Docker startup failed. Exiting..."
        exit 1
    fi
fi

sudo usermod -aG docker $USER
echo "✅ Docker installation completed successfully"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl restart docker
sudo systemctl restart kubelet
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Configure kubelet for low-resource environment
sudo mkdir -p /etc/kubernetes
cat <<EOF | sudo tee /etc/kubernetes/kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 50
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
evictionSoft:
  memory.available: "200Mi"
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "2m"
  nodefs.available: "2m"
systemReserved:
  cpu: "100m"
  memory: "256Mi"
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
cgroupDriver: systemd
clusterDNS:
  - "10.96.0.10"
clusterDomain: "cluster.local"
EOF

# Get the primary IP address more reliably
PRIMARY_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
if [ -z "$PRIMARY_IP" ]; then
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
fi

cat <<EOF | sudo tee /etc/kubernetes/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $PRIMARY_IP
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    config: /etc/kubernetes/kubelet-config.yaml
  ignorePreflightErrors:
    - NumCPU
    - Mem
    - SystemVerification
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
networking:
  podSubnet: "10.244.0.0/16"
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    terminated-pod-gc-threshold: "10"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
etcd:
  local:
    dataDir: "/var/lib/etcd"
    serverCertSANs:
    - "localhost"
    - "127.0.0.1"
    - "$PRIMARY_IP"
    peerCertSANs:
    - "localhost"
    - "127.0.0.1"
    - "$PRIMARY_IP"
EOF

sudo kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml --v=5

if [ $? -ne 0 ]; then
    echo "❌ kubeadm init failed"
    echo "🔍 Checking system resources..."
    free -h
    df -h
    echo "🔍 Checking Docker status..."
    sudo systemctl status docker
    echo "🔍 Checking kubelet logs..."
    sudo journalctl -u kubelet --no-pager --lines=20
    exit 1
fi

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo systemctl restart kubelet
sleep 15

RETRIES=0
MAX_RETRIES=30
while ! kubectl get nodes >/dev/null 2>&1; do
    RETRIES=$((RETRIES + 1))
    if [ $RETRIES -gt $MAX_RETRIES ]; then
        echo "❌ API server failed"
        sudo journalctl -u kubelet --no-pager --lines=10
        exit 1
    fi
    sleep 10
done

kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

kubectl wait --for=condition=Ready node --all --timeout=900s

if [ $? -ne 0 ]; then
    echo "❌ Node failed to become ready"
    kubectl get nodes -o wide
    kubectl get pods -A
    sudo journalctl -u kubelet --no-pager --lines=20
    exit 1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Verify cluster is healthy before installing monitoring
echo "🔍 Verifying cluster health..."
kubectl get nodes -o wide
kubectl get pods -A
free -h
df -h

# Check if we have enough resources for monitoring
AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$AVAILABLE_MEMORY" -lt 1000 ]; then
    echo "⚠️ Low memory detected ($AVAILABLE_MEMORY MB available). Installing minimal monitoring..."
    MONITORING_PROFILE="minimal"
else
    echo "✅ Sufficient memory available ($AVAILABLE_MEMORY MB). Installing standard monitoring..."
    MONITORING_PROFILE="standard"
fi

# Install monitoring with very minimal resources for t3.medium (4GB RAM)
if [ "$MONITORING_PROFILE" = "minimal" ]; then
    echo "🔧 Installing minimal monitoring stack..."
    helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring \
      --set prometheus.prometheusSpec.resources.requests.memory=128Mi \
      --set prometheus.prometheusSpec.resources.limits.memory=256Mi \
      --set prometheus.prometheusSpec.resources.requests.cpu=50m \
      --set prometheus.prometheusSpec.resources.limits.cpu=100m \
      --set grafana.resources.requests.memory=32Mi \
      --set grafana.resources.limits.memory=64Mi \
      --set grafana.resources.requests.cpu=25m \
      --set grafana.resources.limits.cpu=50m \
      --set alertmanager.alertmanagerSpec.resources.requests.memory=32Mi \
      --set alertmanager.alertmanagerSpec.resources.limits.memory=64Mi \
      --set alertmanager.alertmanagerSpec.resources.requests.cpu=25m \
      --set alertmanager.alertmanagerSpec.resources.limits.cpu=50m \
      --set prometheus.prometheusSpec.retention=3h \
      --set prometheus.prometheusSpec.retentionSize=500MB \
      --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=1Gi \
      --set nodeExporter.resources.requests.memory=16Mi \
      --set nodeExporter.resources.limits.memory=32Mi \
      --set kubeStateMetrics.resources.requests.memory=16Mi \
      --set kubeStateMetrics.resources.limits.memory=32Mi \
      --set prometheusOperator.resources.requests.memory=32Mi \
      --set prometheusOperator.resources.limits.memory=64Mi \
      --timeout=900s
else
    echo "🔧 Installing standard monitoring stack..."
    helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring \
      --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
      --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
      --set prometheus.prometheusSpec.resources.requests.cpu=100m \
      --set prometheus.prometheusSpec.resources.limits.cpu=200m \
      --set grafana.resources.requests.memory=64Mi \
      --set grafana.resources.limits.memory=128Mi \
      --set grafana.resources.requests.cpu=50m \
      --set grafana.resources.limits.cpu=100m \
      --set alertmanager.alertmanagerSpec.resources.requests.memory=64Mi \
      --set alertmanager.alertmanagerSpec.resources.limits.memory=128Mi \
      --set alertmanager.alertmanagerSpec.resources.requests.cpu=50m \
      --set alertmanager.alertmanagerSpec.resources.limits.cpu=100m \
      --set prometheus.prometheusSpec.retention=6h \
      --set prometheus.prometheusSpec.retentionSize=1GB \
      --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
      --set nodeExporter.resources.requests.memory=32Mi \
      --set nodeExporter.resources.limits.memory=64Mi \
      --set kubeStateMetrics.resources.requests.memory=32Mi \
      --set kubeStateMetrics.resources.limits.memory=64Mi \
      --set prometheusOperator.resources.requests.memory=64Mi \
      --set prometheusOperator.resources.limits.memory=128Mi \
      --timeout=900s
fi

if [ $? -ne 0 ]; then
    echo "⚠️ Monitoring failed, but Kubernetes ready"
    echo "✅ Setup complete! Logout/login, then run deploy-ec2.sh"
    echo "💡 To install monitoring later, run: helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring --set prometheus.prometheusSpec.resources.requests.memory=256Mi --set prometheus.prometheusSpec.resources.limits.memory=512Mi --set grafana.resources.requests.memory=64Mi --set grafana.resources.limits.memory=128Mi --timeout=900s"
    exit 0
fi

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=600s
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

# Final system optimizations
echo "🔧 Applying final optimizations..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Enable memory compaction
echo 1 | sudo tee /proc/sys/vm/compact_memory

# Final verification
echo "🔍 Final cluster verification..."
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null || true
kubectl top nodes 2>/dev/null || echo "⚠️ Metrics not ready yet"

echo "✅ Setup complete! Logout/login, then run deploy-ec2.sh"
echo "📊 Monitoring: http://$NODE_IP:30300 (admin:$GRAFANA_PASSWORD)"
echo "💡 For t3.medium optimized setup - Monitor resource usage with 'kubectl top nodes' and 'kubectl top pods -A'"
echo "🎯 Memory profile used: $MONITORING_PROFILE"
