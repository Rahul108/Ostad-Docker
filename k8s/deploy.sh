#!/bin/bash

# Ostad K8s Deployment Script
echo "🚀 Deploying Ostad Application to Kubernetes..."

# Build Docker images locally
echo "📦 Building Docker images..."
eval $(minikube docker-env)
docker build -t ostad-server:latest -f Dockerfile-server .
docker build -t ostad-ui-prod:latest -f Dockerfile-UI-prod .

# Apply Kubernetes manifests
echo "🔧 Applying Kubernetes manifests..."

# Apply in order of dependencies
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/mongo-deployment.yaml

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongo -n aninda-sarker-rahul-ns --timeout=300s

# Deploy other services
kubectl apply -f k8s/server-deployment.yaml

# Wait for server to be ready
echo "⏳ Waiting for server to be ready..."
kubectl wait --for=condition=ready pod -l app=ostad-server -n aninda-sarker-rahul-ns --timeout=300s

kubectl apply -f k8s/ui-deployment.yaml
kubectl apply -f k8s/mongo-express-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for all pods to be ready
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all -n aninda-sarker-rahul-ns --timeout=300s

echo "✅ Deployment completed!"
echo ""
echo "📊 Checking deployment status..."
kubectl get pods -n aninda-sarker-rahul-ns
echo ""
kubectl get services -n aninda-sarker-rahul-ns
echo ""
kubectl get ingress -n aninda-sarker-rahul-ns

echo ""
echo "🌐 Access URLs:"
echo "Frontend: http://ostad.local (add to /etc/hosts)"
echo "Mongo Express: http://mongo.local (add to /etc/hosts)"
echo ""
echo "📝 For WSL users accessing from Windows browser:"
echo "Run: ./k8s/wsl-windows-access.sh"
echo "Then access via: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "📝 For Linux/local access, add to /etc/hosts:"
echo "echo '192.168.49.2 ostad.local mongo.local' | sudo tee -a /etc/hosts"
