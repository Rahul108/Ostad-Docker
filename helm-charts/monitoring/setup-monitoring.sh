#!/bin/bash

echo "🔧 Setting up Prometheus monitoring stack..."

# Add Prometheus Helm repo
echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install or upgrade Prometheus stack
echo "Installing/upgrading Prometheus monitoring stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if helm list -n monitoring | grep -q "monitor"; then
    echo "Upgrading existing Prometheus stack..."
    helm upgrade monitor prometheus-community/kube-prometheus-stack --namespace monitoring
else
    echo "Installing new Prometheus stack..."
    helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring
fi

# Wait for Grafana to be ready and expose it
echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s

echo "Exposing Grafana with NodePort..."
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

echo "✅ Monitoring setup completed!"
echo ""
echo "📦 Monitoring pods status:"
kubectl get pods -n monitoring
echo ""
echo "🔗 Monitoring services:"
kubectl get svc -n monitoring
echo ""

MINIKUBE_IP=$(minikube ip)
GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "📊 Monitoring Access:"
echo "  Grafana: http://$MINIKUBE_IP:30300 (login: admin:$GRAFANA_PASSWORD)"
echo "  WSL2 Users: Run ./port-forward.sh then use http://localhost:3000"
echo ""
echo "🎯 Grafana Dashboard Import:"
echo "  Dashboard ID suggestions: 315, 1860 (Kubernetes cluster monitoring)"
echo "  To import: Grafana UI -> + -> Import -> Enter Dashboard ID -> Load"
echo ""
echo "💡 To see monitoring resources:"
echo "  kubectl get all -n monitoring"
echo "  kubectl get pods -n monitoring"
