#!/bin/bash

# Tailscale Connectivity Validation Script
# Comprehensive testing of all Tailscale use-cases from external devices

set -e

echo "🔗 Tailscale Connectivity Validation"
echo "===================================="

# Configuration
TAILNET_DOMAIN="${TAILNET_DOMAIN:-your-tailnet.ts.net}"
TIMEOUT=10

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running on Tailscale network
check_tailscale_connection() {
    log_info "Checking Tailscale connection..."
    
    if command -v tailscale &> /dev/null; then
        if tailscale status | grep -q "Logged in"; then
            log_info "✅ Connected to Tailscale network"
            TAILNET_DOMAIN=$(tailscale status | grep "tailnet:" | awk '{print $2}' || echo "$TAILNET_DOMAIN")
        else
            log_error "❌ Not logged into Tailscale. Run: tailscale up"
            exit 1
        fi
    else
        log_warn "⚠️  Tailscale CLI not found. Assuming connection exists."
    fi
}

# Test API Server Proxy connectivity
test_api_server_proxy() {
    echo
    log_info "Testing API Server Proxy connectivity..."
    
    API_URL="https://k8s-api-proxy.${TAILNET_DOMAIN}:6443"
    
    # Method A: Basic connectivity
    if curl -k -s --max-time $TIMEOUT "$API_URL/healthz" > /dev/null 2>&1; then
        log_info "✅ API server proxy reachable"
    else
        log_warn "⚠️  API server proxy not reachable at $API_URL"
    fi
    
    # Method B: API version check
    if curl -k -s --max-time $TIMEOUT "$API_URL/version" | grep -q "gitVersion"; then
        log_info "✅ API server responding with version info"
    else
        log_warn "⚠️  API server not responding with version info"
    fi
    
    # Method C: DNS resolution
    if nslookup "k8s-api-proxy.${TAILNET_DOMAIN}" > /dev/null 2>&1; then
        log_info "✅ DNS resolution working for API proxy"
    else
        log_warn "⚠️  DNS resolution failed for API proxy"
    fi
}

# Test Cluster Ingress connectivity
test_cluster_ingress() {
    echo
    log_info "Testing Cluster Ingress connectivity..."
    
    INGRESS_URL="http://k8s-ingress.${TAILNET_DOMAIN}"
    
    # Method A: HTTP connectivity
    if curl -s --max-time $TIMEOUT "$INGRESS_URL" | grep -q "nginx\|Welcome"; then
        log_info "✅ Cluster ingress serving content"
    else
        log_warn "⚠️  Cluster ingress not serving expected content"
    fi
    
    # Method B: HTTP headers check
    if curl -I -s --max-time $TIMEOUT "$INGRESS_URL" | grep -q "200 OK"; then
        log_info "✅ Cluster ingress returning 200 OK"
    else
        log_warn "⚠️  Cluster ingress not returning 200 OK"
    fi
    
    # Method C: Ping test
    if ping -c 1 -W $TIMEOUT "k8s-ingress.${TAILNET_DOMAIN}" > /dev/null 2>&1; then
        log_info "✅ Cluster ingress responding to ping"
    else
        log_warn "⚠️  Cluster ingress not responding to ping"
    fi
}

# Test Egress Proxy connectivity
test_egress_proxy() {
    echo
    log_info "Testing Egress Proxy connectivity..."
    
    EGRESS_URL="http://k8s-egress.${TAILNET_DOMAIN}"
    
    # Method A: Basic connectivity
    if ping -c 1 -W $TIMEOUT "k8s-egress.${TAILNET_DOMAIN}" > /dev/null 2>&1; then
        log_info "✅ Egress proxy reachable via ping"
    else
        log_warn "⚠️  Egress proxy not reachable via ping"
    fi
    
    # Method B: DNS resolution
    if nslookup "k8s-egress.${TAILNET_DOMAIN}" > /dev/null 2>&1; then
        log_info "✅ DNS resolution working for egress proxy"
    else
        log_warn "⚠️  DNS resolution failed for egress proxy"
    fi
    
    # Method C: Tailscale status check
    if command -v tailscale &> /dev/null; then
        if tailscale status | grep -q "k8s-egress"; then
            log_info "✅ Egress proxy visible in Tailscale status"
        else
            log_warn "⚠️  Egress proxy not visible in Tailscale status"
        fi
    fi
}

# Test Subnet Router connectivity
test_subnet_router() {
    echo
    log_info "Testing Subnet Router connectivity..."
    
    # Method A: Tailscale status check
    if command -v tailscale &> /dev/null; then
        if tailscale status | grep -q "k8s-subnet-router"; then
            log_info "✅ Subnet router visible in Tailscale status"
        else
            log_warn "⚠️  Subnet router not visible in Tailscale status"
        fi
        
        # Check for advertised routes
        if tailscale status | grep -q "10.100.0.0/16"; then
            log_info "✅ Subnet routes advertised (10.100.0.0/16)"
        else
            log_warn "⚠️  Subnet routes not visible in status"
        fi
    fi
    
    # Method B: Route table check (if available)
    if command -v ip &> /dev/null; then
        if ip route | grep -q "10.100.0.0/16"; then
            log_info "✅ Subnet routes in local routing table"
        else
            log_warn "⚠️  Subnet routes not in local routing table"
        fi
    fi
    
    # Method C: DNS resolution
    if nslookup "k8s-subnet-router.${TAILNET_DOMAIN}" > /dev/null 2>&1; then
        log_info "✅ DNS resolution working for subnet router"
    else
        log_warn "⚠️  DNS resolution failed for subnet router"
    fi
}

# Generate connectivity report
generate_report() {
    echo
    log_info "Generating connectivity report..."
    
    cat > tailscale-connectivity-report.txt << EOF
Tailscale EKS Connectivity Report
Generated: $(date)
Tailnet Domain: ${TAILNET_DOMAIN}

=== Device Status ===
$(tailscale status 2>/dev/null || echo "Tailscale CLI not available")

=== DNS Resolution Tests ===
k8s-api-proxy.${TAILNET_DOMAIN}: $(nslookup "k8s-api-proxy.${TAILNET_DOMAIN}" 2>/dev/null | grep "Address:" | tail -1 || echo "Failed")
k8s-egress.${TAILNET_DOMAIN}: $(nslookup "k8s-egress.${TAILNET_DOMAIN}" 2>/dev/null | grep "Address:" | tail -1 || echo "Failed")
k8s-ingress.${TAILNET_DOMAIN}: $(nslookup "k8s-ingress.${TAILNET_DOMAIN}" 2>/dev/null | grep "Address:" | tail -1 || echo "Failed")
k8s-subnet-router.${TAILNET_DOMAIN}: $(nslookup "k8s-subnet-router.${TAILNET_DOMAIN}" 2>/dev/null | grep "Address:" | tail -1 || echo "Failed")

=== Connectivity Tests ===
API Server: $(curl -k -s --max-time 5 "https://k8s-api-proxy.${TAILNET_DOMAIN}:6443/healthz" 2>/dev/null || echo "Failed")
Ingress: $(curl -s --max-time 5 "http://k8s-ingress.${TAILNET_DOMAIN}" 2>/dev/null | head -1 || echo "Failed")
Egress Ping: $(ping -c 1 -W 5 "k8s-egress.${TAILNET_DOMAIN}" > /dev/null 2>&1 && echo "Success" || echo "Failed")
Subnet Router Ping: $(ping -c 1 -W 5 "k8s-subnet-router.${TAILNET_DOMAIN}" > /dev/null 2>&1 && echo "Success" || echo "Failed")
EOF
    
    log_info "✅ Report saved to tailscale-connectivity-report.txt"
}

# Main execution
main() {
    check_prerequisites
    test_api_server_proxy
    test_egress_proxy
    test_cluster_ingress
    test_subnet_router
    generate_report
    
    echo
    log_info "🎉 Connectivity testing complete!"
    log_info "📋 Check tailscale-connectivity-report.txt for detailed results"
    log_info "🌐 Visit https://login.tailscale.com/admin/machines to see all devices"
}

# Handle script arguments
case "${1:-}" in
    "api") test_api_server_proxy ;;
    "egress") test_egress_proxy ;;
    "ingress") test_cluster_ingress ;;
    "subnet") test_subnet_router ;;
    "report") generate_report ;;
    *) main ;;
esac
