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

echo "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "Creating namespace..."
kubectl create namespace monitoring

echo "Installing minimal monitoring stack..."
# Ultra-minimal values for very constrained environments - Grafana only
cat > /tmp/minimal-monitoring.yaml << 'EOF'
# Disable all heavy components including Prometheus operator
alertmanager:
  enabled: false
  
nodeExporter:
  enabled: false
  
kubeStateMetrics:
  enabled: false

# Disable Prometheus completely to avoid operator issues
prometheus:
  enabled: false
    
# Disable Prometheus Operator completely
prometheusOperator:
  enabled: false

# Only enable Grafana with basic configuration
grafana:
  enabled: true
  image:
    tag: "9.5.0"
  resources:
    requests:
      memory: 64Mi
      cpu: 50m
    limits:
      memory: 128Mi
      cpu: 100m
  persistence:
    enabled: false
  sidecar:
    datasources:
      enabled: false
    dashboards:
      enabled: false
    resources:
      requests:
        memory: 32Mi
        cpu: 25m
      limits:
        memory: 64Mi
        cpu: 50m
  rbac:
    create: false
    pspEnabled: false
  serviceAccount:
    create: false
  testFramework:
    enabled: false
  adminPassword: "admin123"
EOF

helm install monitor prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/minimal-monitoring.yaml \
  --timeout 5m \
  --wait \
  --debug

echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

echo "Patching Grafana service to NodePort..."
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

# Get access info
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
GRAFANA_PASSWORD="admin123"

echo ""
echo "🔍 Checking deployment status..."
kubectl get pods -n monitoring -o wide

if kubectl get pods -n monitoring | grep -q "Running"; then
    echo ""
    echo "✅ Grafana-only monitoring stack deployed!"
    echo "📊 Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
    echo ""
    echo "⚠️  Grafana-only setup:"
    echo "  - Only Grafana (no Prometheus operator)"
    echo "  - No data collection (you'll need to add data sources manually)"
    echo "  - Expected usage: ~200Mi memory, ~50Mi disk"
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
