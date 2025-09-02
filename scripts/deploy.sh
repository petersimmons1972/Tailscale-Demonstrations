#!/bin/bash
set -e

echo "🚀 Deploying Tailscale EKS Infrastructure"

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ aws cli is required but not installed."; exit 1; }

# Deploy infrastructure
echo "📦 Deploying EKS cluster..."
terraform init
terraform plan
terraform apply -auto-approve

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw region)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Deploy Tailscale operator
echo "🔗 Deploying Tailscale operator..."
kubectl apply -f k8s-manifests/tailscale-operator.yaml

# Wait for operator to be ready
echo "⏳ Waiting for Tailscale operator..."
kubectl wait --for=condition=available --timeout=300s deployment/operator -n tailscale

echo "✅ Infrastructure deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Create OAuth credentials at https://login.tailscale.com/admin/settings/oauth"
echo "2. Update k8s-manifests/oauth-secret-template.yaml with your credentials"
echo "3. Apply the OAuth secret: kubectl apply -f k8s-manifests/oauth-secret.yaml"
echo "4. Deploy use cases: kubectl apply -f k8s-manifests/tailscale-usecases.yaml"
echo ""
echo "Your cluster endpoint: $(terraform output -raw cluster_endpoint)"
echo "Your tailnet will be accessible at: https://login.tailscale.com/admin/machines"
