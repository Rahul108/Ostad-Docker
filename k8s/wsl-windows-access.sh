#!/bin/bash

# WSL-Windows Access Script for Ostad Kubernetes Application
echo "🌐 Setting up WSL-Windows access for Ostad application..."

# Get WSL IP address
WSL_IP=$(hostname -I | awk '{print $1}')
echo "📍 WSL IP Address: $WSL_IP"

# Get minikube IP
MINIKUBE_IP=$(minikube ip)
echo "📍 Minikube IP Address: $MINIKUBE_IP"

echo ""
echo "🔧 Setting up port forwarding..."

# Kill any existing port forwards
echo "🧹 Cleaning up existing port forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true

# Set up port forwarding for frontend (UI)
echo "🌐 Setting up frontend port forward..."
kubectl port-forward -n aninda-sarker-rahul-ns service/ostad-ui 8080:80 --address 0.0.0.0 &
FRONTEND_PID=$!

# Set up port forwarding for mongo-express
echo "🗄️ Setting up mongo-express port forward..."
kubectl port-forward -n aninda-sarker-rahul-ns service/mongo-express 8081:8081 --address 0.0.0.0 &
MONGO_EXPRESS_PID=$!

# Set up port forwarding for backend API (optional, for direct access)
echo "🔧 Setting up backend API port forward..."
kubectl port-forward -n aninda-sarker-rahul-ns service/ostad-server 5050:5050 --address 0.0.0.0 &
BACKEND_PID=$!

# Wait a moment for port forwards to establish
sleep 3

echo ""
echo "✅ Port forwarding setup complete!"
echo ""
echo "🌐 Access URLs from Windows Browser:"
echo "📱 Frontend Application:"
echo "   http://$WSL_IP:8080"
echo "   http://localhost:8080 (if WSL2 with latest Windows)"
echo ""
echo "🗄️ Mongo Express (Database UI):"
echo "   http://$WSL_IP:8081"
echo "   http://localhost:8081 (if WSL2 with latest Windows)"
echo "   Username: admin"
echo "   Password: password"
echo ""
echo "🔧 Backend API (Direct Access):"
echo "   http://$WSL_IP:5050"
echo "   http://localhost:5050 (if WSL2 with latest Windows)"
echo ""
echo "📝 Note: Keep this terminal open to maintain port forwarding"
echo "📝 Press Ctrl+C to stop all port forwards"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up port forwards..."
    kill $FRONTEND_PID $MONGO_EXPRESS_PID $BACKEND_PID 2>/dev/null || true
    pkill -f "kubectl port-forward" 2>/dev/null || true
    echo "✅ Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Keep script running
echo "⏳ Port forwarding active. Press Ctrl+C to stop..."
wait
