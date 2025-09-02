#!/bin/bash

# Tailscale EKS Use-Case Testing Script
# Tests all 4 Tailscale use-cases with multiple validation methods

set -e

echo "🧪 Tailscale EKS Use-Case Testing"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! kubectl get ns tailscale &> /dev/null; then
        log_error "Tailscale namespace not found. Please deploy the manifests first."
        exit 1
    fi
    
    log_info "Prerequisites check passed ✅"
}

# Test 1: API Server Proxy
test_api_proxy() {
    echo
    log_info "Testing API Server Proxy..."
    
    # Method A: Pod status check
    if kubectl get pod -n tailscale -l app=api-proxy | grep -q Running; then
        log_info "✅ API proxy pod is running"
    else
        log_error "❌ API proxy pod not running"
        return 1
    fi
    
    # Method B: Service endpoint check
    if kubectl get endpoints -n tailscale api-proxy-service | grep -q "6443"; then
        log_info "✅ API proxy service has endpoints"
    else
        log_warn "⚠️  API proxy service has no endpoints"
    fi
    
    # Method C: Tailscale status
    log_info "Checking Tailscale connection status..."
    kubectl exec -n tailscale deployment/api-proxy -- tailscale status 2>/dev/null || log_warn "Could not get Tailscale status"
}

# Test 2: Cluster Egress
test_egress_proxy() {
    echo
    log_info "Testing Cluster Egress Proxy..."
    
    # Method A: Pod status check
    if kubectl get pod -n tailscale -l app=egress-proxy | grep -q Running; then
        log_info "✅ Egress proxy pod is running"
    else
        log_error "❌ Egress proxy pod not running"
        return 1
    fi
    
    # Method B: External connectivity test
    log_info "Testing external connectivity..."
    if kubectl exec -n tailscale deployment/egress-proxy -- curl -s --max-time 10 https://api.ipify.org > /dev/null; then
        log_info "✅ External connectivity working"
    else
        log_warn "⚠️  External connectivity test failed"
    fi
    
    # Method C: Network configuration
    log_info "Checking network routes..."
    kubectl exec -n tailscale deployment/egress-proxy -- ip route | head -5 || log_warn "Could not get routes"
}

# Test 3: Cluster Ingress
test_ingress_proxy() {
    echo
    log_info "Testing Cluster Ingress Proxy..."
    
    # Method A: Pod status check
    if kubectl get pod -n tailscale -l app=ingress-proxy | grep -q "2/2.*Running"; then
        log_info "✅ Ingress proxy pod is running (2/2 containers)"
    else
        log_error "❌ Ingress proxy pod not running properly"
        return 1
    fi
    
    # Method B: Nginx configuration check
    log_info "Checking nginx proxy configuration..."
    if kubectl get configmap -n tailscale ingress-nginx-config &> /dev/null; then
        log_info "✅ Nginx configuration exists"
    else
        log_warn "⚠️  Nginx configuration missing"
    fi
    
    # Method C: Internal connectivity test
    log_info "Testing internal service connectivity..."
    if kubectl exec -n tailscale deployment/ingress-proxy -c nginx-proxy -- curl -s --max-time 5 http://test-app-service:80 > /dev/null; then
        log_info "✅ Internal service connectivity working"
    else
        log_warn "⚠️  Internal service connectivity test failed"
    fi
}

# Test 4: Subnet Router
test_subnet_router() {
    echo
    log_info "Testing Subnet Router..."
    
    # Method A: Pod status check
    if kubectl get pod -n tailscale -l app=subnet-router | grep -q Running; then
        log_info "✅ Subnet router pod is running"
    else
        log_error "❌ Subnet router pod not running"
        return 1
    fi
    
    # Method B: Route advertisement check
    log_info "Checking advertised routes..."
    if kubectl exec -n tailscale deployment/subnet-router -- tailscale status 2>/dev/null | grep -q "10.100.0.0/16"; then
        log_info "✅ Routes advertised successfully"
    else
        log_warn "⚠️  Could not verify route advertisement"
    fi
    
    # Method C: Pod network access test
    log_info "Testing pod network access..."
    POD_IP=$(kubectl get pod -n tailscale -l app=test-app -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")
    if [[ -n "$POD_IP" ]]; then
        log_info "✅ Test app pod IP: $POD_IP"
        # Test internal connectivity to pod IP
        if kubectl run test-connectivity --image=curlimages/curl --rm -i --restart=Never -- curl -s --max-time 5 http://$POD_IP > /dev/null 2>&1; then
            log_info "✅ Pod direct access working"
        else
            log_warn "⚠️  Pod direct access test failed"
        fi
    else
        log_warn "⚠️  Could not get test app pod IP"
    fi
}

# Main execution
main() {
    check_prerequisites
    
    echo
    log_info "Starting Tailscale use-case testing..."
    
    test_api_proxy
    test_egress_proxy  
    test_ingress_proxy
    test_subnet_router
    
    echo
    log_info "Testing Summary:"
    echo "=================="
    kubectl get pods -n tailscale
    echo
    log_info "🎉 All Tailscale use-cases tested!"
    log_info "Check your Tailscale admin console: https://login.tailscale.com/admin/machines"
    log_info "You should see 4 devices: k8s-api-proxy, k8s-egress, k8s-ingress, k8s-subnet-router"
}

# Run main function
main "$@"
