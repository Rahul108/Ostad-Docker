# Ostad Helm Deployment

This repository contains Helm charts for deploying the Ostad application stack on Kubernetes.

## Prerequisites

- Docker
- Kubernetes cluster (minikube, kind, or any other)
- kubectl configured

## Quick Start

### 1. Install Helm 3

```bash
cd helm-charts
./install-helm.sh
```

### 2. Deploy the application

```bash
./deploy.sh
```

This will:
- Build Docker images for ostad-server and ostad-ui
- Install all Helm charts in the correct order
- Wait for services to be ready
- Display access URLs

### 3. Access the application

- **Frontend (Ostad UI)**: http://localhost:30173
- **Mongo Express**: http://localhost:30081
- **API endpoints**: http://localhost:30050

## Manual Installation

If you prefer to install each component manually:

### 1. Build Docker images

```bash
docker build -f helm-charts/Dockerfile-server -t ostad-server:latest .
docker build -f helm-charts/Dockerfile-ui -t ostad-ui:latest .
```

### 2. Install Helm charts

```bash
cd helm-charts

# Install MongoDB first
helm install mongo ./mongo

# Install Mongo Express
helm install mongo-express ./mongo-express

# Install Ostad Server
helm install ostad-server ./ostad-server

# Install Ostad UI
helm install ostad-ui ./ostad-ui
```

### 3. Verify deployment

```bash
kubectl get pods
kubectl get svc
```

## Chart Structure

- `mongo/` - MongoDB database
- `mongo-express/` - MongoDB web interface
- `ostad-server/` - Express.js backend API
- `ostad-ui/` - React frontend application

## Configuration

Each chart has a `values.yaml` file with configurable options:

### MongoDB Configuration
- Username/Password: `ostad/ostad`
- Database: Uses default MongoDB port 27017

### Mongo Express Configuration
- Port: 8081 (NodePort: 30081)
- Connects to MongoDB using credentials

### Ostad Server Configuration
- Port: 5050 (NodePort: 30050)
- MongoDB connection string configured

### Ostad UI Configuration
- Port: 5173 (NodePort: 30173)
- Static React build served via nginx

## Cleanup

To remove all installations:

```bash
helm uninstall ostad-ui
helm uninstall ostad-server
helm uninstall mongo-express
helm uninstall mongo
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods
kubectl logs <pod-name>
```

### Check services
```bash
kubectl get svc
```

### Port forwarding (alternative access)
```bash
kubectl port-forward svc/ostad-ui 3000:5173
kubectl port-forward svc/ostad-server 5000:5050
kubectl port-forward svc/mongo-express 8081:8081
```
