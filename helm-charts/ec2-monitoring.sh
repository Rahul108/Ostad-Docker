#!/bin/bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create values file for resource-limited monitoring stack
cat > /tmp/monitoring-values.yaml << 'EOF'
# Disable resource-intensive components
alertmanager:
  enabled: false
  
nodeExporter:
  enabled: false
  
kubeStateMetrics:
  enabled: true
  
# Grafana with minimal resources
grafana:
  enabled: true
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 256Mi
      cpu: 200m
  persistence:
    enabled: false
  sidecar:
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 100m

# Prometheus with minimal resources and short retention
prometheus:
  enabled: true
  prometheusSpec:
    resources:
      requests:
        memory: 256Mi
        cpu: 200m
      limits:
        memory: 512Mi
        cpu: 400m
    retention: 1d
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 500Mi
    serviceMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    
# Disable Prometheus Operator webhook to save resources
prometheusOperator:
  admissionWebhooks:
    enabled: false
  resources:
    requests:
      memory: 64Mi
      cpu: 50m
    limits:
      memory: 128Mi
      cpu: 100m
EOF

if helm list -n monitoring | grep -q "monitor"; then
    helm upgrade monitor prometheus-community/kube-prometheus-stack --namespace monitoring -f /tmp/monitoring-values.yaml
else
    helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring -f /tmp/monitoring-values.yaml
fi

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

# Clean up temporary values file
rm -f /tmp/monitoring-values.yaml

EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "Monitoring URLs:"
echo "  Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
echo ""
echo "📋 Resource-limited monitoring stack deployed:"
echo "  - AlertManager: Disabled"
echo "  - Node Exporter: Disabled" 
echo "  - Prometheus: Limited to 512Mi memory, 1 day retention"
echo "  - Grafana: Limited to 256Mi memory"
echo "  - Total expected usage: ~800Mi memory, ~500Mi disk"
