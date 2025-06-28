#!/bin/bash

# Alternative WSL-Windows Access using Minikube Tunnel
echo "🚇 Setting up Minikube tunnel for WSL-Windows access..."

echo "🔧 Starting minikube tunnel (requires sudo)..."
echo "📝 Note: You may be prompted for your password"

# Start minikube tunnel in background
sudo minikube tunnel &
TUNNEL_PID=$!

echo "⏳ Waiting for tunnel to establish..."
sleep 5

# Get the external IP assigned by the tunnel
EXTERNAL_IP=$(kubectl get ingress ostad-ingress -n aninda-sarker-rahul-ns -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$EXTERNAL_IP" ]; then
    echo "⏳ Waiting for LoadBalancer IP assignment..."
    kubectl wait --for=condition=Available ingress/ostad-ingress -n aninda-sarker-rahul-ns --timeout=60s
    EXTERNAL_IP=$(kubectl get ingress ostad-ingress -n aninda-sarker-rahul-ns -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

if [ -n "$EXTERNAL_IP" ]; then
    echo ""
    echo "✅ Minikube tunnel established!"
    echo ""
    echo "🌐 Access URLs from Windows Browser:"
    echo "📱 Frontend: http://$EXTERNAL_IP"
    echo "🗄️ Mongo Express: http://$EXTERNAL_IP:8081"
    echo ""
    echo "📝 Add this to Windows hosts file (C:\\Windows\\System32\\drivers\\etc\\hosts):"
    echo "$EXTERNAL_IP ostad.local"
    echo "$EXTERNAL_IP mongo.local"
    echo ""
    echo "📝 Then access via:"
    echo "📱 Frontend: http://ostad.local"
    echo "🗄️ Mongo Express: http://mongo.local"
else
    echo "❌ Failed to get external IP. Tunnel may not be working properly."
fi

echo ""
echo "📝 Keep this terminal open to maintain the tunnel"
echo "📝 Press Ctrl+C to stop the tunnel"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Stopping minikube tunnel..."
    sudo kill $TUNNEL_PID 2>/dev/null || true
    sudo pkill -f "minikube tunnel" 2>/dev/null || true
    echo "✅ Tunnel stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Keep script running
echo "⏳ Tunnel active. Press Ctrl+C to stop..."
wait $TUNNEL_PID
