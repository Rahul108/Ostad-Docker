#!/bin/bash

cd /home/pyro/ostad_projects/ostad-module-5

echo "Building Docker images..."
eval $(minikube docker-env)
docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .

echo "Deploying services..."
cd helm-charts

# Install services
helm install mongo ./mongo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo --timeout=100s

helm install mongo-express ./mongo-express
helm install ostad-server ./ostad-server
helm install ostad-ui ./ostad-ui

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-server --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-ui --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo-express --timeout=100s

echo "✅ Deployment completed!"
echo ""
kubectl get pods
echo ""
MINIKUBE_IP=$(minikube ip)
echo "🌐 Access URLs:"
echo "  WSL2 Users: Run ./port-forward.sh then use localhost"
echo "  Direct: http://$MINIKUBE_IP:30173 (UI) | http://$MINIKUBE_IP:30081 (DB) | http://$MINIKUBE_IP:30050 (API)"
echo "  Mongo Express login: admin/ostad123"
echo ""
echo "📊 For monitoring setup, run: ./setup-monitoring.sh"
