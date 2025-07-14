# Ostad Helm Deployment

Deploy the Ostad application stack (MongoDB, Express API, React UI) on Kubernetes using Helm.

## Prerequisites

- Docker
- Minikube or Kubernetes cluster
- kubectl configured

## Quick Start

### 1. Deploy Everything

```bash
cd helm-charts
./deploy.sh
```

This script will:
- Build Docker images
- Install all Helm charts
- Show you access URLs

### 2. Access Your Application

**For WSL2 Users (Windows):**

*Option 1: Use the port-forward script (Easy):*
```bash
./port-forward.sh
```

*Option 2: Manual port forwarding:*
```bash
# Run in separate terminals
kubectl port-forward service/ostad-ui 5173:5173
kubectl port-forward service/mongo-express 8081:8081
kubectl port-forward service/ostad-server 5050:5050
```

Then access from Windows:
- **Frontend**: http://localhost:5173
- **Mongo Express**: http://localhost:8081 (admin:ostad123)
- **API Server**: http://localhost:5050

**For Direct Access (Linux/Mac):**
- Get Minikube IP: `minikube ip`
- Frontend: `http://<minikube-ip>:30173`
- Mongo Express: `http://<minikube-ip>:30081` (admin:ostad123)
- API Server: `http://<minikube-ip>:30050`

## What's Included

- **MongoDB** - Database (port 27017)
- **Mongo Express** - Database web UI (port 8081)
- **Ostad Server** - Express.js API (port 5050)
- **Ostad UI** - React frontend (port 5173)
- **Monitoring** - Grafana monitoring stack (see `monitoring/` folder)

## Monitoring

For monitoring deployment, see the `monitoring/` folder:

```bash
# Deploy lightweight monitoring (recommended for EC2)
./monitoring/ec2-monitoring-minimal.sh

# Access Grafana
# Direct: http://EC2_IP:30300 (admin:admin123)
# Port forwarding: ./ec2-port-forward.sh then http://EC2_IP:3000
```

For more monitoring options, see `monitoring/README.md`

## EC2 Deployment

For EC2 instances, use the specialized scripts:

```bash
# Deploy application
./ec2-deploy.sh

# Deploy monitoring
./monitoring/ec2-monitoring-minimal.sh

# Port forwarding for external access
./ec2-port-forward.sh
```

## Cleanup

```bash
helm uninstall ostad-ui ostad-server mongo-express mongo
```

## Troubleshooting

```bash
# Check pod status
kubectl get pods

# Check logs
kubectl logs <pod-name>

# Check services
kubectl get svc
```
