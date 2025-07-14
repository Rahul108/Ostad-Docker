#!/bin/bash

echo "🔧 Quick fix for ImagePullBackOff issues..."

# Check if it's a storage issue
echo "1. Checking for storage issues..."
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring 2>/dev/null

# Delete stuck pods to force recreation
echo "2. Restarting stuck pods..."
kubectl delete pod -n monitoring --grace-period=0 --force --field-selector=status.phase=Pending 2>/dev/null || true
kubectl delete pod -n monitoring --grace-period=0 --force --field-selector=status.phase=Failed 2>/dev/null || true

# Scale down and up to force recreation
echo "3. Scaling down and up deployments..."
kubectl scale deployment monitor-grafana -n monitoring --replicas=0
kubectl scale deployment monitor-kube-prometheus-st-operator -n monitoring --replicas=0
sleep 5
kubectl scale deployment monitor-grafana -n monitoring --replicas=1
kubectl scale deployment monitor-kube-prometheus-st-operator -n monitoring --replicas=1

echo "4. Checking pod status..."
kubectl get pods -n monitoring

echo "5. Waiting for pods to be ready (60s timeout)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=60s || echo "Grafana still not ready"

echo "6. Current pod status:"
kubectl get pods -n monitoring

echo ""
echo "If pods are still failing, run: chmod +x diagnose-monitoring.sh && ./diagnose-monitoring.sh"
echo "Or try the minimal setup: chmod +x ec2-monitoring-minimal.sh && ./ec2-monitoring-minimal.sh"
