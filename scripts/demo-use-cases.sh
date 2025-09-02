#!/bin/bash

# Tailscale EKS Use-Case Demo Script
# Interactive demonstration of all 4 Tailscale use-cases

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[DEMO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_cmd() { echo -e "${YELLOW}[CMD]${NC} $1"; }

# Demo configuration
TAILNET_DOMAIN="${TAILNET_DOMAIN:-your-tailnet.ts.net}"

echo "🎬 Tailscale EKS Use-Case Demo"
echo "=============================="
echo "This script demonstrates all 4 Tailscale use-cases"
echo "Replace 'your-tailnet.ts.net' with your actual tailnet domain"
echo

# Demo 1: API Server Proxy
demo_api_server_proxy() {
    log_info "Demo 1: API Server Proxy"
    echo "Access Kubernetes API securely through Tailscale"
    echo
    
    log_step "1. Check API proxy pod status"
    log_cmd "kubectl get pods -n tailscale -l app=api-proxy"
    kubectl get pods -n tailscale -l app=api-proxy
    echo
    
    log_step "2. Test API server health"
    log_cmd "curl -k https://k8s-api-proxy.${TAILNET_DOMAIN}:6443/healthz"
    echo "Expected: 'ok'"
    echo
    
    log_step "3. Configure kubectl to use Tailscale API proxy"
    echo "Run these commands to access your cluster remotely:"
    echo "kubectl config set-cluster tailscale-cluster \\"
    echo "  --server=https://k8s-api-proxy.${TAILNET_DOMAIN}:6443 \\"
    echo "  --insecure-skip-tls-verify=true"
    echo
    echo "kubectl config set-context tailscale-context \\"
    echo "  --cluster=tailscale-cluster --user=\$(kubectl config current-context | cut -d'@' -f2)"
    echo
    echo "kubectl config use-context tailscale-context"
    echo "kubectl get nodes"
    echo
}

# Demo 2: Cluster Egress
demo_cluster_egress() {
    log_info "Demo 2: Cluster Egress Proxy"
    echo "Route cluster traffic through Tailscale network"
    echo
    
    log_step "1. Check egress proxy status"
    log_cmd "kubectl get pods -n tailscale -l app=egress-proxy"
    kubectl get pods -n tailscale -l app=egress-proxy
    echo
    
    log_step "2. Test external connectivity via egress"
    log_cmd "kubectl exec -n tailscale deployment/egress-proxy -- curl -s https://api.ipify.org"
    kubectl exec -n tailscale deployment/egress-proxy -- curl -s https://api.ipify.org 2>/dev/null || echo "Connection test failed"
    echo
    
    log_step "3. Check Tailscale connection status"
    log_cmd "kubectl exec -n tailscale deployment/egress-proxy -- tailscale status"
    kubectl exec -n tailscale deployment/egress-proxy -- tailscale status 2>/dev/null || echo "Tailscale status unavailable"
    echo
}

# Demo 3: Cluster Ingress
demo_cluster_ingress() {
    log_info "Demo 3: Cluster Ingress Proxy"
    echo "Expose cluster services to Tailscale network"
    echo
    
    log_step "1. Check ingress proxy status"
    log_cmd "kubectl get pods -n tailscale -l app=ingress-proxy"
    kubectl get pods -n tailscale -l app=ingress-proxy
    echo
    
    log_step "2. Test ingress service access"
    log_cmd "curl http://k8s-ingress.${TAILNET_DOMAIN}"
    echo "Expected: nginx welcome page"
    echo "Try this from any Tailscale device:"
    echo "curl http://k8s-ingress.${TAILNET_DOMAIN}"
    echo
    
    log_step "3. Check nginx proxy configuration"
    log_cmd "kubectl get configmap -n tailscale ingress-nginx-config -o yaml"
    kubectl get configmap -n tailscale ingress-nginx-config -o yaml | grep -A 10 "default.conf"
    echo
}

# Demo 4: Subnet Router
demo_subnet_router() {
    log_info "Demo 4: Subnet Router"
    echo "Access pod and service networks directly via Tailscale"
    echo
    
    log_step "1. Check subnet router status"
    log_cmd "kubectl get pods -n tailscale -l app=subnet-router"
    kubectl get pods -n tailscale -l app=subnet-router
    echo
    
    log_step "2. Show advertised routes"
    log_cmd "kubectl exec -n tailscale deployment/subnet-router -- tailscale status"
    kubectl exec -n tailscale deployment/subnet-router -- tailscale status 2>/dev/null || echo "Tailscale status unavailable"
    echo
    
    log_step "3. Test direct pod access"
    POD_IP=$(kubectl get pod -n tailscale -l app=test-app -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
    if [[ -n "$POD_IP" ]]; then
        log_cmd "curl http://${POD_IP} (from Tailscale device)"
        echo "Test app pod IP: $POD_IP"
        echo "From any Tailscale device, run: curl http://$POD_IP"
    else
        echo "Could not get test app pod IP"
    fi
    echo
    
    log_step "4. Show service IPs for direct access"
    log_cmd "kubectl get services -n tailscale -o wide"
    kubectl get services -n tailscale -o wide
    echo "Access services directly via their Cluster-IP from Tailscale devices"
    echo
}

# Interactive demo menu
interactive_demo() {
    while true; do
        echo
        echo "🎬 Select a demo to run:"
        echo "1) API Server Proxy"
        echo "2) Cluster Egress"
        echo "3) Cluster Ingress"
        echo "4) Subnet Router"
        echo "5) Run All Demos"
        echo "6) Exit"
        echo
        read -p "Enter choice [1-6]: " choice
        
        case $choice in
            1) demo_api_server_proxy ;;
            2) demo_cluster_egress ;;
            3) demo_cluster_ingress ;;
            4) demo_subnet_router ;;
            5) 
                demo_api_server_proxy
                demo_cluster_egress
                demo_cluster_ingress
                demo_subnet_router
                ;;
            6) 
                log_info "Demo complete! 🎉"
                break
                ;;
            *) echo "Invalid choice. Please enter 1-6." ;;
        esac
    done
}

# Main execution
main() {
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check if tailscale namespace exists
    if ! kubectl get ns tailscale &> /dev/null; then
        echo "❌ Tailscale namespace not found. Please deploy the manifests first."
        exit 1
    fi
    
    # Run interactive demo or specific demo
    case "${1:-}" in
        "api") demo_api_server_proxy ;;
        "egress") demo_cluster_egress ;;
        "ingress") demo_cluster_ingress ;;
        "subnet") demo_subnet_router ;;
        "all")
            demo_api_server_proxy
            demo_cluster_egress
            demo_cluster_ingress
            demo_subnet_router
            ;;
        *) interactive_demo ;;
    esac
}

# Run main function
main "$@"
