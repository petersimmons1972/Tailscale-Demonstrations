#!/bin/bash
set -e

echo "🧹 Cleaning up Tailscale EKS Infrastructure"

# Remove Kubernetes resources first
echo "Removing Kubernetes resources..."
kubectl delete -f k8s-manifests/tailscale-usecases.yaml --ignore-not-found=true
kubectl delete -f k8s-manifests/tailscale-operator.yaml --ignore-not-found=true
kubectl delete -f k8s-manifests/oauth-secret.yaml --ignore-not-found=true

# Wait a moment for resources to be cleaned up
sleep 10

# Destroy Terraform infrastructure
echo "Destroying Terraform infrastructure..."
terraform destroy -auto-approve

echo "✅ Cleanup completed!"
echo "Don't forget to remove devices from your Tailscale admin panel if needed:"
echo "https://login.tailscale.com/admin/machines"
