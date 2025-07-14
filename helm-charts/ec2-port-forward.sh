#!/bin/bash

echo "Setting up port forwarding for EC2 access..."
echo "This will make the services accessible from your local machine at localhost:port"
echo ""

# Kill any existing port-forward processes
pkill -f "kubectl port-forward"

echo "Starting port forwarding for all services..."

# Port forward in background (bind to all interfaces for external access)
kubectl port-forward --address 0.0.0.0 service/mongo-express 8081:8081 &
kubectl port-forward --address 0.0.0.0 service/ostad-server 5050:5050 &
kubectl port-forward --address 0.0.0.0 service/ostad-ui 5173:5173 &

# Port forward monitoring services (if available)
if kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "Monitoring namespace detected, forwarding Grafana..."
    kubectl port-forward --address 0.0.0.0 service/monitor-grafana 3000:80 -n monitoring &
    # Only try to forward Prometheus if the service exists
    if kubectl get service monitor-kube-prometheus-st-prometheus -n monitoring > /dev/null 2>&1; then
        kubectl port-forward --address 0.0.0.0 service/monitor-kube-prometheus-st-prometheus 9090:9090 -n monitoring &
    fi
fi

echo ""
echo "Port forwarding active! Access your services from your PC browser at:"
# Get EC2 public IP using IMDSv2, fallback to external service
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null)
if [ -n "$TOKEN" ]; then
    EC2_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
fi
# Fallback to external service if metadata service fails
if [ -z "$EC2_IP" ]; then
    EC2_IP=$(curl -s https://checkip.amazonaws.com/ 2>/dev/null | tr -d '\n')
fi
echo "  - Frontend (Ostad UI): http://$EC2_IP:5173"
echo "  - Mongo Express: http://$EC2_IP:8081 (admin:ostad123)"
echo "  - API Server: http://$EC2_IP:5050"

# Show monitoring URLs if available
if kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "  - Grafana: http://$EC2_IP:3000 (admin:admin123)"
    if kubectl get service monitor-kube-prometheus-st-prometheus -n monitoring > /dev/null 2>&1; then
        echo "  - Prometheus: http://$EC2_IP:9090"
    fi
fi

# Show minikube direct access URLs
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
echo ""
echo "Direct minikube access (from EC2 instance):"
echo "  - Frontend (Ostad UI): http://$MINIKUBE_IP:30173"
echo "  - Mongo Express: http://$MINIKUBE_IP:30081 (admin:ostad123)"
echo "  - API Server: http://$MINIKUBE_IP:30050"
if kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "  - Grafana: http://$MINIKUBE_IP:30300 (admin:admin123)"
fi
echo ""
echo "📋 Security Group Requirements (already configured for all TCP):"
echo "  - Port 5173 (Ostad UI)"
echo "  - Port 8081 (Mongo Express)"  
echo "  - Port 5050 (API Server)"
echo "  - Port 3000 (Grafana)"
echo "  - Port 9090 (Prometheus)"
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo ""

# Wait for all background processes
wait
