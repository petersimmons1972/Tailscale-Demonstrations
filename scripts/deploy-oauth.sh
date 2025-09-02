#!/bin/bash

# Tailscale Kubernetes Operator Deployment with OAuth
# This script safely deploys Tailscale using OAuth credentials

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Tailscale Kubernetes Operator Deployment${NC}"
echo "=============================================="

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please create .env file with your OAuth credentials:"
    echo "cp .env.example .env"
    echo "Then edit .env with your actual values"
    exit 1
fi

# Load environment variables
source .env

# Validate credentials
if [[ -z "$TAILSCALE_OAUTH_CLIENT_ID" || -z "$TAILSCALE_OAUTH_CLIENT_SECRET" ]]; then
    echo -e "${RED}❌ Error: OAuth credentials not set${NC}"
    echo "Please set TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET in .env"
    exit 1
fi

echo -e "${YELLOW}📋 Prerequisites check...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm not found${NC}"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Clean up any existing deployment
echo -e "${YELLOW}🧹 Cleaning up existing deployment...${NC}"
kubectl delete namespace tailscale --ignore-not-found=true

# Add Tailscale Helm repository
echo -e "${YELLOW}📦 Adding Tailscale Helm repository...${NC}"
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

# Deploy Tailscale operator with OAuth
echo -e "${YELLOW}🚀 Deploying Tailscale operator...${NC}"
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="$TAILSCALE_OAUTH_CLIENT_ID" \
  --set-string oauth.clientSecret="$TAILSCALE_OAUTH_CLIENT_SECRET" \
  --wait

# Wait for operator to be ready
echo -e "${YELLOW}⏳ Waiting for operator to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/operator -n tailscale

# Show status
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Operator status:"
kubectl get pods -n tailscale
echo ""
echo "To create Tailscale services, use Kubernetes resources like:"
echo "- ProxyClass, Connector, Ingress with tailscale IngressClass"
echo ""
echo "Check your Tailscale admin console for new devices!"
