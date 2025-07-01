# Ostad Kubernetes Deployment

This directory contains Kubernetes manifests to deploy the Ostad full-stack application.


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

## File Structure
```
k8s/
├── namespace.yaml                 # Creates namespace for resource isolation
├── configmap.yaml                 # Non-sensitive configuration (database names, ports, hosts)
├── secret.yaml                    # Sensitive credentials (gitignored - copy from sample)
├── secret.yaml.sample             # Template for secrets with placeholder values
├── mongo-deployment.yaml          # MongoDB database with persistent volume and service
├── server-deployment.yaml         # Node.js backend API with ConfigMap/Secret refs
├── ui-deployment.yaml             # React frontend served by nginx
├── mongo-express-deployment.yaml  # MongoDB web admin interface
├── ingress.yaml                   # NGINX ingress rules for chat.local and mongo.local
├── deploy.sh                      # Automated deployment script
├── wsl-windows-access.sh          # Port forwarding for Windows browser access
└── README.md                      # This documentation
```


## Deployment

### Quick Deployment

**Prerequisites**: Make sure to setup secrets first (see Manual Deployment step 1).

Use the provided deployment script:

```bash
# First setup secrets:
cp k8s/secret.yaml.sample k8s/secret.yaml
# Edit k8s/secret.yaml with your base64 encoded credentials

# Then run deployment:
./k8s/deploy.sh
```

This script will:
1. Build Docker images locally
2. Apply all Kubernetes manifests (including your secrets)
3. Wait for pods to be ready
4. Display deployment status

### Manual Deployment

#### 1. **Setup Secrets (REQUIRED FIRST STEP):**
   
Before deploying, you must create the secrets file for sensitive data:

```bash
# Copy the sample secrets file
cp k8s/secret.yaml.sample k8s/secret.yaml

# Edit the secrets file with your own values
# Replace <base64_encoded_*> placeholders with actual base64 encoded values
nano k8s/secret.yaml  # or use your preferred editor

# To generate base64 encoded values:
echo -n "your_username" | base64
echo -n "your_password" | base64

# Example - encoding "admin":
echo -n "admin" | base64
# Output: YWRtaW4=
```

**Important**: The `secret.yaml` file is gitignored for security. Always use strong passwords in production!

#### 2. **Build Docker images:**
```bash
eval $(minikube docker-env)
docker build -t ostad-server:latest -f Dockerfile-server .
docker build -t ostad-ui-prod:latest -f Dockerfile-UI-prod .
```

#### 3. **Apply manifests in order:**
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml          # Apply your secrets
kubectl apply -f k8s/mongo-deployment.yaml
kubectl apply -f k8s/server-deployment.yaml
kubectl apply -f k8s/ui-deployment.yaml
kubectl apply -f k8s/mongo-express-deployment.yaml
kubectl apply -f k8s/ingress.yaml
```

#### 4. **Add local DNS entries:**
```bash
echo '192.168.49.2 chat.local mongo.local' | sudo tee -a /etc/hosts
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

- **Frontend**: http://chat.local
- **Backend API**: http://chat.local/api
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

## Troubleshooting

1. **Pods not starting**: Check resource limits and node capacity
2. **Image not found**: Ensure Docker images are built locally or available in registry
3. **Ingress not working**: Verify NGINX Ingress Controller is installed and running
4. **DNS not resolving**: Check `/etc/hosts` entries for chat.local and mongo.local
5. **Database connection issues**: Verify MongoDB is ready before other services start
