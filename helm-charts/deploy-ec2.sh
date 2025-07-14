#!/bin/bash

cd /home/pyro/ostad_projects/ostad-module-5

echo "🐳 Building and deploying..."

docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .

echo "📥 Loading images into containerd..."
docker save ostad-server:latest -o /tmp/ostad-server.tar
docker save ostad-ui:latest -o /tmp/ostad-ui.tar
sudo ctr -n k8s.io image import /tmp/ostad-server.tar
sudo ctr -n k8s.io image import /tmp/ostad-ui.tar
rm -f /tmp/ostad-server.tar /tmp/ostad-ui.tar

cd helm-charts

helm install mongo ./mongo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo --timeout=100s

helm install mongo-express ./mongo-express
helm install ostad-server ./ostad-server
helm install ostad-ui ./ostad-ui

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-server --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-ui --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo-express --timeout=100s

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo "✅ Deployed! Access at:"
echo "  Frontend: http://$NODE_IP:30173"
echo "  Mongo Express: http://$NODE_IP:30081 (admin/ostad123)"
echo "  API Server: http://$NODE_IP:30050"
