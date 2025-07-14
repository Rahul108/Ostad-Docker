#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

eval $(minikube docker-env)
docker system prune -f
docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker system prune -f
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .
docker system prune -f

cd helm-charts

# Uninstall existing releases if they exist
helm uninstall mongo 2>/dev/null || true
helm uninstall mongo-express 2>/dev/null || true
helm uninstall ostad-server 2>/dev/null || true
helm uninstall ostad-ui 2>/dev/null || true

# Wait for pods to be deleted
kubectl wait --for=delete pod -l app.kubernetes.io/instance=mongo --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app.kubernetes.io/instance=mongo-express --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app.kubernetes.io/instance=ostad-server --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pod -l app.kubernetes.io/instance=ostad-ui --timeout=60s 2>/dev/null || true

helm install mongo ./mongo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo --timeout=100s

helm install mongo-express ./mongo-express
helm install ostad-server ./ostad-server
helm install ostad-ui ./ostad-ui

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-server --timeout=100s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-ui --timeout=100s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo-express --timeout=100s 2>/dev/null || true

kubectl get pods

docker system prune -f

EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

echo "Access URLs:"
echo "  UI: http://$EC2_IP:30173 | DB: http://$EC2_IP:30081 | API: http://$EC2_IP:30050"
echo "  Mongo Express: admin/ostad123"
echo "  Run ./ec2-monitoring.sh for monitoring setup"
