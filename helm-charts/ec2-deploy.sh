#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

eval $(minikube docker-env)
docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .

cd helm-charts

helm install mongo ./mongo
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo --timeout=100s

helm install mongo-express ./mongo-express
helm install ostad-server ./ostad-server
helm install ostad-ui ./ostad-ui

kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-server --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=ostad-ui --timeout=100s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=mongo-express --timeout=100s

kubectl get pods

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if helm list -n monitoring | grep -q "monitor"; then
    helm upgrade monitor prometheus-community/kube-prometheus-stack --namespace monitoring
else
    helm install monitor prometheus-community/kube-prometheus-stack --namespace monitoring
fi

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s
kubectl patch svc monitor-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30300}]}}'

EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
GRAFANA_PASSWORD=$(kubectl get secret monitor-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "Access URLs:"
echo "  UI: http://$EC2_IP:30173 | DB: http://$EC2_IP:30081 | API: http://$EC2_IP:30050"
echo "  Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
echo "  Mongo Express: admin/ostad123"
