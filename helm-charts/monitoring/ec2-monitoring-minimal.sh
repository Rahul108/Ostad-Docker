#!/bin/bash

# Exit on any error
set -e

# Function to handle cleanup on exit
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f /tmp/minimal-monitoring.yaml
}
trap cleanup EXIT

echo "Cleaning up existing monitoring deployment..."
helm uninstall monitor -n monitoring 2>/dev/null || true
kubectl delete namespace monitoring 2>/dev/null || true

echo "Waiting for cleanup..."
sleep 15

echo "Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "Creating namespace..."
kubectl create namespace monitoring

echo "Installing minimal monitoring stack..."
# Ultra-minimal Grafana-only deployment using standalone chart
cat > /tmp/minimal-monitoring.yaml << 'EOF'
# Minimal resource allocation for EC2
resources:
  requests:
    memory: 64Mi
    cpu: 50m
  limits:
    memory: 128Mi
    cpu: 100m

# Disable persistence
persistence:
  enabled: false

# Set admin password
adminPassword: "admin123"

# Disable unnecessary features
sidecar:
  datasources:
    enabled: false
  dashboards:
    enabled: false

# Minimal RBAC
rbac:
  create: false
  pspEnabled: false

serviceAccount:
  create: false

# Disable test framework
testFramework:
  enabled: false

# Use NodePort service
service:
  type: NodePort
  nodePort: 30300
  port: 80

# Disable ingress
ingress:
  enabled: false
EOF

helm install monitor grafana/grafana \
  --namespace monitoring \
  --values /tmp/minimal-monitoring.yaml \
  --timeout 5m \
  --wait

echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Get access info
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
GRAFANA_PASSWORD="admin123"

echo ""
echo "🔍 Checking deployment status..."
kubectl get pods -n monitoring -o wide

if kubectl get pods -n monitoring | grep -q "Running"; then
    echo ""
    echo "✅ Standalone Grafana deployed successfully!"
    echo "📊 Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
    echo "📊 Or via port forwarding: http://$EC2_IP:3000 (when using ./ec2-port-forward.sh)"
    echo ""
    echo "⚠️  Standalone Grafana setup:"
    echo "  - Only Grafana (no monitoring stack overhead)"
    echo "  - No data collection (you'll need to add data sources manually)"
    echo "  - Expected usage: ~100Mi memory, ~20Mi disk"
    echo ""
    echo "💡 To add Prometheus later, you can:"
    echo "  - Install standalone Prometheus"
    echo "  - Configure it as a data source in Grafana"
else
    echo ""
    echo "❌ Some pods are not running properly. Check the status above."
    echo "💡 You can check pod logs with: kubectl logs -n monitoring <pod-name>"
    echo "📊 Grafana might still be accessible at: http://$EC2_IP:30300"
fi
