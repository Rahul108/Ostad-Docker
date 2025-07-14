#!/bin/bash

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

echo "Monitoring URLs:"
echo "  Grafana: http://$EC2_IP:30300 (admin:$GRAFANA_PASSWORD)"
