#!/bin/bash

# Ostad K8s Deployment Script
echo "🚀 Deploying Ostad Application to Kubernetes..."

# Build Docker images locally
echo "📦 Building Docker images..."
docker build -t ostad-server:latest -f Dockerfile-server .
docker build -t ostad-ui:latest -f Dockerfile-UI .

# Apply Kubernetes manifests
echo "🔧 Applying Kubernetes manifests..."

# Apply in order of dependencies
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/mongo-deployment.yaml

# Wait for MongoDB to be ready
echo "⏳ Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongo -n pyro-ns --timeout=300s

# Deploy other services
kubectl apply -f k8s/server-deployment.yaml

# Wait for server to be ready
echo "⏳ Waiting for server to be ready..."
kubectl wait --for=condition=ready pod -l app=ostad-server -n pyro-ns --timeout=300s

kubectl apply -f k8s/ui-deployment.yaml
kubectl apply -f k8s/mongo-express-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for all pods to be ready
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all -n pyro-ns --timeout=300s

echo "✅ Deployment completed!"
echo ""
echo "📊 Checking deployment status..."
kubectl get pods -n pyro-ns
echo ""
kubectl get services -n pyro-ns
echo ""
kubectl get ingress -n pyro-ns

echo ""
echo "🌐 Access URLs:"
echo "Frontend: http://chat.local (add to /etc/hosts)"
echo "Mongo Express: http://mongo.local (add to /etc/hosts)"
echo ""
echo "To add to /etc/hosts, run:"
echo "echo '127.0.0.1 chat.local mongo.local' | sudo tee -a /etc/hosts"
