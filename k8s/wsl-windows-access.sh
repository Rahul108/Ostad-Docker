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

# Set up port forwarding for ingress (for domain access)
echo "🌐 Setting up ingress port forward for domain access..."
echo "ℹ️  Attempting to use port 80 for clean URLs (no port numbers)"

# Check if we can bind to port 80 without sudo
if netstat -tuln | grep -q ":80 "; then
    echo "⚠️  Port 80 is already in use, falling back to port 8000"
    kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8000:80 8443:443 --address 0.0.0.0 &
    INGRESS_PID=$!
    INGRESS_PORT=8000
else
    # Try to set capabilities for kubectl to bind to port 80
    KUBECTL_PATH=$(which kubectl)
    if sudo setcap 'cap_net_bind_service=+ep' "$KUBECTL_PATH" 2>/dev/null; then
        echo "✅ Enabled port 80 binding capability"
        kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 80:80 443:443 --address 0.0.0.0 &
        INGRESS_PID=$!
        INGRESS_PORT=80
    else
        echo "⚠️  Cannot bind to port 80, using port 8000 instead"
        kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8000:80 8443:443 --address 0.0.0.0 &
        INGRESS_PID=$!
        INGRESS_PORT=8000
    fi
fi

# Wait a moment for port forwards to establish
sleep 5

echo ""
echo "✅ Port forwarding setup complete!"
echo ""
echo "🌐 Access URLs from Windows Browser:"
echo ""
echo "📱 Frontend Application:"
echo "   http://$WSL_IP:8080 (direct service access)"
echo "   http://localhost:8080 (if WSL2 with latest Windows)"
if [ "$INGRESS_PORT" = "80" ]; then
    echo "   http://chat.local (via ingress + hosts file)"
else
    echo "   http://chat.local:$INGRESS_PORT (via ingress + hosts file)"
fi
echo ""
echo "🗄️ Mongo Express (Database UI):"
echo "   http://$WSL_IP:8081 (direct service access)"
echo "   http://localhost:8081 (if WSL2 with latest Windows)"
if [ "$INGRESS_PORT" = "80" ]; then
    echo "   http://mongo.local (via ingress + hosts file)"
else
    echo "   http://mongo.local:$INGRESS_PORT (via ingress + hosts file)"
fi
echo "   Username: admin"
echo "   Password: password"
echo ""
echo "🔧 Backend API (Direct Access):"
echo "   http://$WSL_IP:5050 (direct service access)"
echo "   http://localhost:5050 (if WSL2 with latest Windows)"
if [ "$INGRESS_PORT" = "80" ]; then
    echo "   http://chat.local/api (via ingress + hosts file)"
else
    echo "   http://chat.local:$INGRESS_PORT/api (via ingress + hosts file)"
fi
echo ""
echo "🔧 Windows Hosts File Setup (for domain access):"
echo "   Add to C:\\Windows\\System32\\drivers\\etc\\hosts:"
echo "   $WSL_IP chat.local"
echo "   $WSL_IP mongo.local"
echo ""
echo "📝 Note: Keep this terminal open to maintain port forwarding"
echo "📝 Press Ctrl+C to stop all port forwards"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up port forwards..."
    kill $FRONTEND_PID $MONGO_EXPRESS_PID $BACKEND_PID $INGRESS_PID 2>/dev/null || true
    pkill -f "kubectl port-forward" 2>/dev/null || true
    echo "✅ Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Keep script running
echo "⏳ Port forwarding active. Press Ctrl+C to stop..."
wait
