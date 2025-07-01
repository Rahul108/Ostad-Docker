#!/bin/bash

# Ostad K8s Deployment Script
echo "🚀 Deploying Ostad Application to Kubernetes..."

# Build Docker images locally
echo "📦 Building Docker images..."
eval $(minikube docker-env)
docker build -t ostad-server:latest -f Dockerfile-server .
docker build -t ostad-ui-prod:latest -f Dockerfile-UI-prod .

# Apply Kubernetes manifests
echo "🔧 Applying manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/mongo-deployment.yaml

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB..."
kubectl wait --for=condition=ready pod -l app=mongo -n aninda-sarker-rahul-ns --timeout=300s

# Deploy other services
kubectl apply -f k8s/server-deployment.yaml
kubectl wait --for=condition=ready pod -l app=ostad-server -n aninda-sarker-rahul-ns --timeout=300s

kubectl apply -f k8s/ui-deployment.yaml
kubectl apply -f k8s/mongo-express-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for all pods to be ready
echo "⏳ Waiting for all pods..."
kubectl wait --for=condition=ready pod --all -n aninda-sarker-rahul-ns --timeout=300s

echo "✅ Deployment completed!"
echo ""
kubectl get pods -n aninda-sarker-rahul-ns
echo ""
echo "🌐 Access URLs:"
echo "Frontend: http://chat.local"
echo "Mongo Express: http://mongo.local"
echo ""
echo "📝 WSL users: ./k8s/wsl-windows-access.sh"
