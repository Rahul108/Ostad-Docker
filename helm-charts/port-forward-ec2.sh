#!/bin/bash

echo "🚀 Setting up port forwarding..."

setup_port_forward() {
    if [ -n "$4" ]; then
        kubectl port-forward service/$1 $2:$3 -n $4 &
    else
        kubectl port-forward service/$1 $2:$3 &
    fi
    echo $! > /tmp/port-forward-$1.pid
}

pkill -f "kubectl port-forward" 2>/dev/null || true

setup_port_forward "ostad-ui" 5173 5173
setup_port_forward "mongo-express" 8081 8081
setup_port_forward "ostad-server" 5050 5050
setup_port_forward "monitor-grafana" 3000 80 monitoring
setup_port_forward "monitor-kube-prometheus-st-prometheus" 9090 9090 monitoring

echo "✅ Access at:"
echo "  Frontend: http://localhost:5173"
echo "  Mongo Express: http://localhost:8081 (admin/ostad123)"
echo "  API Server: http://localhost:5050"
echo "  Grafana: http://localhost:3000 (admin/[check setup output])"
echo "  Prometheus: http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop..."

trap 'pkill -f "kubectl port-forward"; exit' INT
while true; do
    sleep 1
done
