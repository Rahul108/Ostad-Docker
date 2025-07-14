#!/bin/bash

echo "Cleaning up existing monitoring deployment..."
helm uninstall monitor -n monitoring 2>/dev/null || true
kubectl delete namespace monitoring 2>/dev/null || true

echo "Waiting for cleanup..."
sleep 10

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
      memory: 32Mi
      cpu: 25m
    limits:
      memory: 64Mi
      cpu: 50m
  image:
    tag: "v0.60.0"  # Use a smaller, stable version
EOF

helm install monitor prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/minimal-monitoring.yaml \
  --timeout 600s \
  --wait

echo "Patching Grafana service to NodePort..."
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

# Clean up
rm -f /tmp/minimal-monitoring.yaml

# Get access info
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo ""
echo "✅ Minimal monitoring stack deployed!"
echo "📊 Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
echo ""
echo "⚠️  Ultra-minimal setup:"
echo "  - Only Prometheus + Grafana"
echo "  - 6 hour retention"
echo "  - No persistent storage"
echo "  - Expected usage: ~400Mi memory, ~100Mi disk"
