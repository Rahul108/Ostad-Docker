# Ostad Kubernetes Deployment

This directory contains Kubernetes manifests to deploy the Ostad full-stack application.

## Prerequisites

- Kubernetes 5. **DNS not res## Troubleshooting

1. **Pods not starting**: Check resource limits and node capacity
2. **Image not found**: Ensure Docker images are built locally or available in registry
3. **Ingress not working**: Verify NGINX Ingress Controller is installed and running
4. **DNS not resolving**: Check `/etc/hosts` entries for ostad.local and mongo.local
5. **Database connection issues**: Verify MongoDB is ready before other services start
6. **WSL-Windows access issues**: 
   - Use port forwarding: `./k8s/wsl-windows-access.sh`
   - Check Windows firewall settings
   - Ensure WSL2 is being used for better networking
7. **Port forwarding stops working**: Restart the wsl-windows-access.sh script*: Check `/etc/hosts` entries for ostad.local and mongo.localluster (minikube, Docker Desktop, or cloud provider)
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
- **Frontend (ostad-ui)**: React app built for production and served by nginx
- **Backend (ostad-server)**: Node.js/Express API with MongoDB integration
- **MongoDB**: Database with persistent storage
- **Mongo Express**: Web-based MongoDB administration interface

All resources are deployed in the `aninda-sarker-rahul-ns` namespace.

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
   eval $(minikube docker-env)
   docker build -t ostad-server:latest -f Dockerfile-server .
   docker build -t ostad-ui-prod:latest -f Dockerfile-UI-prod .
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
   echo '192.168.49.2 ostad.local mongo.local' | sudo tee -a /etc/hosts
   ```

## Access the Application

### For WSL Users (Windows Browser Access)

If you're running minikube in WSL and want to access from Windows browser:

#### Option 1: Port Forwarding (Recommended)
```bash
./k8s/wsl-windows-access.sh
```
Then access from Windows browser:
- **Frontend**: http://localhost:8080 or http://[WSL-IP]:8080
- **Mongo Express**: http://localhost:8081 or http://[WSL-IP]:8081
- **Backend API**: http://localhost:5050 or http://[WSL-IP]:5050

#### Option 2: Minikube Tunnel
```bash
./k8s/minikube-tunnel.sh
```
Follow the script instructions to add entries to Windows hosts file.

### For Linux/Direct Access

- **Frontend**: http://ostad.local
- **Backend API**: http://ostad.local/api
- **Mongo Express**: http://mongo.local (username: admin, password: password)

## Monitoring and Debugging

Check pod status:
```bash
kubectl get pods -n aninda-sarker-rahul-ns
```

Check services:
```bash
kubectl get services -n aninda-sarker-rahul-ns
```

Check ingress:
```bash
kubectl get ingress -n aninda-sarker-rahul-ns
```

View pod logs:
```bash
kubectl logs -f deployment/ostad-server -n aninda-sarker-rahul-ns
kubectl logs -f deployment/ostad-ui -n aninda-sarker-rahul-ns
kubectl logs -f deployment/mongo -n aninda-sarker-rahul-ns
kubectl logs -f deployment/mongo-express -n aninda-sarker-rahul-ns
```

Describe resources for troubleshooting:
```bash
kubectl describe pod <pod-name> -n aninda-sarker-rahul-ns
kubectl describe service <service-name> -n aninda-sarker-rahul-ns
```

## Cleanup

To remove all deployed resources:

```bash
./k8s/cleanup.sh
```

Or manually:
```bash
kubectl delete namespace aninda-sarker-rahul-ns
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
├── wsl-windows-access.sh      # WSL-Windows port forwarding setup
├── minikube-tunnel.sh         # Alternative tunnel-based access
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
