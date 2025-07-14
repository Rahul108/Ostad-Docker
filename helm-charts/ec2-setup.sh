#!/bin/bash

echo "🚀 Setting up Kubernetes and monitoring on Ubuntu 22.04..."

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
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

sudo kubeadm init --pod-network-cidr=10.244.0.0/16

if [ $? -ne 0 ]; then
    echo "❌ kubeadm init failed"
    exit 1
fi

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "⏳ Waiting for API server to be ready..."
while ! kubectl get nodes >/dev/null 2>&1; do
    sleep 5
done

kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

kubectl wait --for=condition=Ready node --all --timeout=300s

if [ $? -ne 0 ]; then
    echo "❌ Node failed to become ready"
    exit 1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring

if [ $? -ne 0 ]; then
    echo "⚠️ Monitoring setup failed, but Kubernetes is ready"
    echo "✅ Setup complete! Logout and login again, then run deploy-ec2.sh"
    exit 0
fi

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "✅ Setup complete! Logout and login again, then run deploy-ec2.sh"
echo "📊 Monitoring: http://$NODE_IP:30300 (admin:$GRAFANA_PASSWORD)"
