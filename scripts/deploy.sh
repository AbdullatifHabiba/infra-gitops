#!/bin/bash
set -e

echo "=== Deploying Dependency-Track (Multi-Pod Architecture) ==="

# Create namespaces
kubectl create namespace dependency-track-dev --dry-run=client -o yaml | kubectl apply -f -
# kubectl create namespace dependency-track-prod --dry-run=client -o yaml | kubectl apply -f -

# Apply ArgoCD project
kubectl apply -f argo-apps/project.yaml

# Deploy applications
kubectl apply -f argo-apps/dependency-track-dev.yaml

echo "=== Deployment Complete ==="
echo "ArgoCD Applications:"
kubectl get applications -n argocd

echo "=== Pod Architecture ==="
echo "Each environment has:"
echo "- 1x Frontend Pod(s)"
echo "- 1x Backend Pod(s)" 
echo "- 1x Database Pod"
echo "- Persistent Storage"

echo "=== Access Information ==="
echo "ArgoCD UI: https://localhost:8080"
echo "Dev Resources: kubectl get all -n dependency-track-dev"
