# Ostad Helm Deployment

Deploy the Ostad application stack (MongoDB, Express API, React UI) on Kubernetes using Helm.

## Prerequisites

- Docker
- Kubernetes cluster (Minikube or kubeadm)
- kubectl configured

## Deployment Options

### Option 1: AWS EC2 with kubeadm (Recommended for Production)

**1. Setup EC2 Instance:**
- Launch Ubuntu 22.04 EC2 instance (t3.medium or larger)
- Configure security group (see EC2-SETUP.md)
- SSH into your instance

**2. Setup Kubernetes:**
```bash
cd helm-charts
./ec2-setup.sh
```

**3. Deploy Application:**
```bash
./deploy-ec2.sh
```

**4. Access Application:**
- Get your EC2 public IP from AWS console
- Frontend: `http://<ec2-public-ip>:30173`
- Mongo Express: `http://<ec2-public-ip>:30081` (admin/ostad123)
- API Server: `http://<ec2-public-ip>:30050`

**Alternative: Port Forwarding (for development):**
```bash
./port-forward-ec2.sh
```
Then access via localhost URLs.

### Option 2: Local Development with Minikube

**1. Deploy Everything:**

```bash
cd helm-charts
./deploy.sh
```

This script will:
- Build Docker images
- Install all Helm charts
- Show you access URLs

**2. Access Your Application:**

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
