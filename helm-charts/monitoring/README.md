# Monitoring Scripts

This folder contains all monitoring-related scripts for the Ostad project.

## Scripts Overview

### 🚀 Deployment Scripts
- **`ec2-monitoring-minimal.sh`** - Lightweight Grafana-only deployment for EC2 instances
  - Minimal resource usage (~100Mi memory)
  - No Prometheus operator (avoids complexity)
  - NodePort service on port 30300
  - Credentials: admin:admin123

- **`ec2-monitoring.sh`** - Full monitoring stack deployment (may have resource issues on constrained EC2)
  - Includes Prometheus + Grafana
  - Higher resource requirements
  - Use `ec2-monitoring-minimal.sh` for EC2 instances with limited resources

- **`setup-monitoring.sh`** - General monitoring setup script

### 🔧 Maintenance Scripts
- **`diagnose-monitoring.sh`** - Diagnose monitoring deployment issues
  - Check pod status
  - View logs
  - Resource usage analysis

- **`fix-monitoring.sh`** - Fix common monitoring issues
  - Restart failed pods
  - Clean up resources
  - Apply fixes

## Quick Start

For EC2 instances with limited resources:
```bash
./ec2-monitoring-minimal.sh
```

For diagnosis and troubleshooting:
```bash
./diagnose-monitoring.sh
```

## Access Methods

### Direct NodePort Access
- Grafana: `http://EC2_IP:30300` (admin:admin123)

### Port Forwarding
Use the parent directory's `ec2-port-forward.sh` to access via port 3000:
```bash
../ec2-port-forward.sh
```
Then access: `http://EC2_IP:3000`

## Resource Requirements

### Minimal Setup (ec2-monitoring-minimal.sh)
- Memory: ~100Mi
- CPU: ~50m
- Disk: ~20Mi

### Full Setup (ec2-monitoring.sh)
- Memory: ~400Mi+
- CPU: ~200m+
- Disk: ~100Mi+

## Troubleshooting

1. **Pods not starting**: Use `diagnose-monitoring.sh`
2. **Resource constraints**: Use `ec2-monitoring-minimal.sh`
3. **Service issues**: Use `fix-monitoring.sh`
4. **Access problems**: Check NodePort with `kubectl get svc -n monitoring`
