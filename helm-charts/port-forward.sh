#!/bin/bash

echo "Setting up port forwarding for WSL2 access..."
echo "This will make the services accessible from Windows at localhost:port"
echo ""

# Kill any existing port-forward processes
pkill -f "kubectl port-forward"

echo "Starting port forwarding for all services..."

# Port forward in background
kubectl port-forward service/mongo-express 8081:8081 &
kubectl port-forward service/ostad-server 5050:5050 &
kubectl port-forward service/ostad-ui 5173:5173 &

# Port forward monitoring services (if available)
if kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "Monitoring namespace detected, forwarding Grafana and Prometheus..."
    kubectl port-forward service/monitor-grafana 3000:80 -n monitoring &
    kubectl port-forward service/monitor-kube-prometheus-st-prometheus 9090:9090 -n monitoring &
fi

echo ""
echo "Port forwarding active! Access your services from Windows at:"
echo "  - Frontend (Ostad UI): http://localhost:5173"
echo "  - Mongo Express: http://localhost:8081 (admin:ostad123)"
echo "  - API Server: http://localhost:5050"

# Show monitoring URLs if available
if kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "  - Grafana: http://localhost:3000 (admin:prom-operator)"
    echo "  - Prometheus: http://localhost:9090"
fi
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo ""

# Wait for all background processes
wait
