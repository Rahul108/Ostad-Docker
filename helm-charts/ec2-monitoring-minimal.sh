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
# Ultra-minimal values for very constrained environments
cat > /tmp/minimal-monitoring.yaml << 'EOF'
# Disable all heavy components
alertmanager:
  enabled: false
  
nodeExporter:
  enabled: false
  
kubeStateMetrics:
  enabled: false
  
# Minimal Grafana
grafana:
  enabled: true
  image:
    tag: "9.5.0"  # Use a smaller, stable version
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

# Minimal Prometheus
prometheus:
  enabled: true
  prometheusSpec:
    image:
      tag: "v2.40.0"  # Use a smaller, stable version
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
      limits:
        memory: 256Mi
        cpu: 200m
    retention: 6h  # Very short retention
    storageSpec: {}  # Use emptyDir instead of PVC
    serviceMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    
# Minimal Prometheus Operator
prometheusOperator:
  enabled: true
  admissionWebhooks:
    enabled: false
  tls:
    enabled: false
  resources:
    requests:
      memory: 64Mi
      cpu: 50m
    limits:
      memory: 128Mi
      cpu: 100m
  # Remove specific image tag to use default compatible version
  kubeletService:
    enabled: false  # Disable kubelet service to avoid the flag issue
  serviceMonitor:
    selfMonitor: false
EOF

helm install monitor prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/minimal-monitoring.yaml \
  --timeout 10m \
  --wait \
  --debug

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus-operator -n monitoring --timeout=300s

echo "Patching Grafana service to NodePort..."
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

# Get access info
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "admin")

echo ""
echo "🔍 Checking deployment status..."
kubectl get pods -n monitoring -o wide

if kubectl get pods -n monitoring | grep -q "Running"; then
    echo ""
    echo "✅ Minimal monitoring stack deployed!"
    echo "📊 Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
    echo ""
    echo "⚠️  Ultra-minimal setup:"
    echo "  - Only Prometheus + Grafana"
    echo "  - 6 hour retention"
    echo "  - No persistent storage"
    echo "  - Expected usage: ~400Mi memory, ~100Mi disk"
else
    echo ""
    echo "❌ Some pods are not running properly. Check the status above."
    echo "💡 You can check pod logs with: kubectl logs -n monitoring <pod-name>"
    echo "📊 Grafana might still be accessible at: http://$EC2_IP:30300"
fi
