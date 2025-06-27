# Ostad Kubernetes Deployment

This directory contains Kubernetes manifests to deploy the Ostad full-stack application.

## Prerequisites

- Kubernetes cluster (minikube, Docker Desktop, or cloud provider)
- kubectl configured to connect to your cluster
- NGINX Ingress Controller installed in your cluster

### Install NGINX Ingress Controller (if not already installed)

For minikube:
```bash
minikube addons enable ingress
```

For other clusters:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

## Architecture

The application consists of:
- **Frontend (ostad-ui)**: React app served by Vite dev server
- **Backend (ostad-server)**: Node.js/Express API with MongoDB integration
- **MongoDB**: Database with persistent storage
- **Mongo Express**: Web-based MongoDB administration interface

All resources are deployed in the `pyro-ns` namespace.

## Deployment

### Quick Deployment

Use the provided deployment script:

```bash
./k8s/deploy.sh
```

This script will:
1. Build Docker images locally
2. Apply all Kubernetes manifests
3. Wait for pods to be ready
4. Display deployment status

### Manual Deployment

1. **Build Docker images:**
   ```bash
   docker build -t ostad-server:latest -f Dockerfile-server .
   docker build -t ostad-ui:latest -f Dockerfile-UI .
   ```

2. **Apply manifests in order:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/mongo-deployment.yaml
   kubectl apply -f k8s/server-deployment.yaml
   kubectl apply -f k8s/ui-deployment.yaml
   kubectl apply -f k8s/mongo-express-deployment.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

3. **Add local DNS entries:**
   ```bash
   echo '127.0.0.1 chat.local mongo.local' | sudo tee -a /etc/hosts
   ```

## Access the Application

- **Frontend**: http://chat.local
- **Backend API**: http://chat.local/api
- **Mongo Express**: http://mongo.local (username: admin, password: password)

## Monitoring and Debugging

Check pod status:
```bash
kubectl get pods -n pyro-ns
```

Check services:
```bash
kubectl get services -n pyro-ns
```

Check ingress:
```bash
kubectl get ingress -n pyro-ns
```

View pod logs:
```bash
kubectl logs -f deployment/ostad-server -n pyro-ns
kubectl logs -f deployment/ostad-ui -n pyro-ns
kubectl logs -f deployment/mongo -n pyro-ns
kubectl logs -f deployment/mongo-express -n pyro-ns
```

Describe resources for troubleshooting:
```bash
kubectl describe pod <pod-name> -n pyro-ns
kubectl describe service <service-name> -n pyro-ns
```

## Cleanup

To remove all deployed resources:

```bash
./k8s/cleanup.sh
```

Or manually:
```bash
kubectl delete namespace pyro-ns
```

## File Structure

```
k8s/
├── namespace.yaml              # Namespace definition
├── configmap.yaml             # Configuration and secrets
├── mongo-deployment.yaml      # MongoDB deployment, PVC, and service
├── server-deployment.yaml     # Backend API deployment and service
├── ui-deployment.yaml         # Frontend deployment and service
├── mongo-express-deployment.yaml # Mongo Express deployment and service
├── ingress.yaml               # Ingress configuration
├── deploy.sh                  # Deployment script
├── cleanup.sh                 # Cleanup script
└── README.md                  # This file
```

## Notes

- The deployment uses `imagePullPolicy: Never` for local development
- For production, push images to a registry and update the image references
- Persistent storage is configured for MongoDB using PVC
- Health checks are configured for all services
- Basic authentication is enabled for Mongo Express

## Troubleshooting

1. **Pods not starting**: Check resource limits and node capacity
2. **Image not found**: Ensure Docker images are built locally or available in registry
3. **Ingress not working**: Verify NGINX Ingress Controller is installed and running
4. **DNS not resolving**: Check `/etc/hosts` entries for chat.local and mongo.local
5. **Database connection issues**: Verify MongoDB is ready before other services start
