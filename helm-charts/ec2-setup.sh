#!/bin/bash

echo "🚀 Setting up Kubernetes and monitoring for t3.medium..."

# System optimizations for t3.medium (4GB RAM)
sudo sysctl vm.overcommit_memory=1
sudo sysctl vm.panic_on_oom=0
sudo sysctl vm.oom_kill_allocating_task=1
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.panic_on_oom=0' | sudo tee -a /etc/sysctl.conf
echo 'vm.oom_kill_allocating_task=1' | sudo tee -a /etc/sysctl.conf

sudo apt-get update -y
sudo apt-get install -y docker.io apt-transport-https ca-certificates curl
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

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
EOF

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU,Mem --config=/dev/stdin <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $(hostname -I | awk '{print $1}')
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    config: /etc/kubernetes/kubelet-config.yaml
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
    peerCertSANs:
    - "localhost"
    - "127.0.0.1"
EOF

if [ $? -ne 0 ]; then
    echo "❌ kubeadm init failed"
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

# Install monitoring with very minimal resources for t3.medium (4GB RAM)
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

echo "✅ Setup complete! Logout/login, then run deploy-ec2.sh"
echo "📊 Monitoring: http://$NODE_IP:30300 (admin:$GRAFANA_PASSWORD)"
echo "💡 For t3.medium optimized setup - Monitor resource usage with 'kubectl top nodes' and 'kubectl top pods -A'"
