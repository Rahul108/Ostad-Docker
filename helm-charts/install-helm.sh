#!/bin/bash

# Install Helm 3 on node
echo "Installing Helm 3..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Verify installation
helm version

echo "Helm 3 installed successfully!"
