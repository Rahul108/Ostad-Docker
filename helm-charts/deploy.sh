#!/bin/bash

cd /home/pyro/ostad_projects/ostad-module-5

echo "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

echo "Building Docker images inside Minikube..."
docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .

echo "Installing Helm charts..."
cd helm-charts

# Install mongo first (dependency)
helm install mongo ./mongo

# Wait for mongo to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo --timeout=100s

# Install mongo-express
helm install mongo-express ./mongo-express

# Install ostad-server
helm install ostad-server ./ostad-server

# Install ostad-ui
helm install ostad-ui ./ostad-ui

echo "Waiting for all services to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-server --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-ui --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo-express --timeout=100s

echo "Deployment completed!"
echo ""
echo "Services:"
kubectl get pods
echo ""
kubectl get svc
echo ""
echo "Access URLs:"
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"
echo ""
echo "=== FOR WSL2 USERS ==="
echo "If you're using WSL2 and can't access Minikube IP from Windows, use port forwarding:"
echo "Run these commands in separate terminals:"
echo "  kubectl port-forward service/ostad-ui 5173:5173"
echo "  kubectl port-forward service/mongo-express 8081:8081"
echo "  kubectl port-forward service/ostad-server 5050:5050"
echo ""
echo "Then access from Windows at:"
echo "  - Frontend: http://localhost:5173"
echo "  - Mongo Express: http://localhost:8081 (admin:ostad123)"
echo "  - API Server: http://localhost:5050"
echo ""
echo "Or run: ./port-forward.sh"
echo ""
echo "=== DIRECT ACCESS (WSL2 only) ==="
echo "Frontend (Ostad UI): http://$MINIKUBE_IP:30173"
echo "Mongo Express: http://$MINIKUBE_IP:30081 (admin:ostad123)"
echo "API endpoints: http://$MINIKUBE_IP:30050"
echo ""
echo "Alternative access (if minikube service works):"
echo "minikube service ostad-ui --url"
echo "minikube service mongo-express --url"
echo "minikube service ostad-server --url"
