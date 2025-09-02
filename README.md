# Tailscale EKS Infrastructure Demo

## Overview
This project demonstrates a complete Infrastructure as Code solution for deploying Tailscale on AWS EKS. It provisions an EKS cluster and implements three Tailscale operator use-cases:

- **🌐 API Server Proxy** - Secure access to Kubernetes API through Tailscale
- **🚀 Egress Proxy** - Route application traffic through Tailscale 
- **🔗 Subnet Router** - Expose pod and service networks via Tailscale

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS VPC                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Public Subnet │  │   Public Subnet │  │ Public Subnet│ │
│  │                 │  │                 │  │              │ │
│  │  ┌──────────┐   │  │  ┌──────────┐   │  │ ┌──────────┐ │ │
│  │  │EKS Nodes │   │  │  │EKS Nodes │   │  │ │EKS Nodes │ │ │
│  │  │          │   │  │  │          │   │  │ │          │ │ │
│  │  └──────────┘   │  │  └──────────┘   │  │ └──────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                EKS Control Plane                        │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │    Tailscale Network    │
                    │                         │
                    │  • API Server Proxy     │
                    │  • Egress Proxy         │
                    │  • Subnet Router        │
                    └─────────────────────────┘
```

## 📁 Project Structure

```
tailscale/
├── eks-cluster.tf              # EKS cluster infrastructure
├── eks-variables.tf            # Terraform variables
├── eks-outputs.tf              # Terraform outputs
├── versions.tf                 # Provider versions
├── k8s-manifests/
│   ├── tailscale-operator.yaml     # Tailscale operator deployment
│   ├── tailscale-usecases.yaml     # Use case implementations
│   └── oauth-secret-template.yaml  # OAuth credentials template
├── scripts/
│   └── deploy.sh               # Automated deployment script
└── README.md                   # This file
```

## 🚀 Quick Start

### Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.24
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2
- AWS account with EKS permissions
- Tailscale account

### 1. Deploy Infrastructure
```bash
# Clone and navigate to project
git clone <your-repo-url>
cd tailscale/

# Run automated deployment
./scripts/deploy.sh
```

### 2. Configure Tailscale OAuth
1. Visit [Tailscale OAuth settings](https://login.tailscale.com/admin/settings/oauth)
2. Create a new OAuth client with these scopes:
   - `device:create`
   - `device:read`
   - `device:write`
3. Copy `k8s-manifests/oauth-secret-template.yaml` to `oauth-secret.yaml`
4. Fill in your OAuth credentials:
```bash
cp k8s-manifests/oauth-secret-template.yaml k8s-manifests/oauth-secret.yaml
# Edit oauth-secret.yaml with your credentials
kubectl apply -f k8s-manifests/oauth-secret.yaml
```

### 3. Deploy Tailscale Use Cases
```bash
kubectl apply -f k8s-manifests/tailscale-usecases.yaml
```

### 4. Verify Deployment
```bash
# Check operator status
kubectl get pods -n tailscale

# Check Tailscale devices in your admin panel
# Visit: https://login.tailscale.com/admin/machines

# Test connectivity to exposed services
curl http://k8s-test-app.your-tailnet.ts.net
```

## 🎯 Use Cases Implemented

### 1. API Server Proxy
Exposes the Kubernetes API server through Tailscale, allowing secure remote access to your cluster without VPN.

**Access:** `k8s-api-proxy.your-tailnet.ts.net`

### 2. Egress Proxy  
Routes application traffic through Tailscale network, useful for accessing internal services or implementing zero-trust networking.

**Access:** `k8s-egress.your-tailnet.ts.net`

### 3. Subnet Router
Exposes the entire pod and service network (10.100.0.0/16, 10.96.0.0/12) through Tailscale, enabling direct access to any pod or service.

**Access:** Direct IP access to pods/services via Tailscale

## 🔧 Configuration

### Cluster Specifications
- **Provider:** AWS EKS
- **Node Type:** t3.medium
- **Node Count:** 2-3 nodes (auto-scaling)
- **Kubernetes Version:** Latest stable
- **Networking:** VPC with public/private subnets

### Tailscale Configuration
- **Operator Image:** `tailscale/k8s-operator:latest`
- **Proxy Image:** `tailscale/tailscale:latest`
- **Security:** Non-root containers, read-only filesystems
- **RBAC:** Minimal required permissions

## 🛠️ Manual Deployment Steps

If you prefer manual deployment:

```bash
# 1. Deploy infrastructure
terraform init
terraform apply

# 2. Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name tailscale-demo-cluster

# 3. Deploy Tailscale operator
kubectl apply -f k8s-manifests/tailscale-operator.yaml

# 4. Configure OAuth (see step 2 above)

# 5. Deploy use cases
kubectl apply -f k8s-manifests/tailscale-usecases.yaml
```

## 🧪 Testing & Validation

Each Tailscale use-case can be tested using three different mechanisms:

### 1. API Server Proxy Testing

**Method A: Remote kubectl Access**
```bash
# Configure kubectl to use Tailscale API proxy
kubectl config set-cluster tailscale-cluster \
  --server=https://k8s-api-proxy.your-tailnet.ts.net:6443 \
  --insecure-skip-tls-verify=true

kubectl config set-context tailscale-context \
  --cluster=tailscale-cluster \
  --user=your-aws-user

kubectl config use-context tailscale-context
kubectl get nodes
```

**Method B: Direct API Calls**
```bash
# Get cluster info via Tailscale
curl -k https://k8s-api-proxy.your-tailnet.ts.net:6443/api/v1/namespaces

# Test with authentication token
TOKEN=$(kubectl get secret -n default -o jsonpath='{.items[0].data.token}' | base64 -d)
curl -k -H "Authorization: Bearer $TOKEN" \
  https://k8s-api-proxy.your-tailnet.ts.net:6443/api/v1/nodes
```

**Method C: Health Check**
```bash
# Verify API proxy pod logs
kubectl logs -n tailscale deployment/api-proxy
kubectl get endpoints -n tailscale api-proxy-service
```

### 2. Cluster Egress Testing

**Method A: Pod-to-External Service**
```bash
# Test egress through Tailscale from within cluster
kubectl run test-egress --image=curlimages/curl -it --rm -- \
  curl -v http://k8s-egress.your-tailnet.ts.net

# Test external connectivity via egress proxy
kubectl exec -n tailscale deployment/egress-proxy -- \
  curl -s https://api.ipify.org
```

**Method B: Network Route Verification**
```bash
# Check egress proxy routes
kubectl exec -n tailscale deployment/egress-proxy -- ip route
kubectl exec -n tailscale deployment/egress-proxy -- tailscale status
```

**Method C: Traffic Analysis**
```bash
# Monitor egress proxy logs
kubectl logs -n tailscale deployment/egress-proxy -f
kubectl describe pod -n tailscale -l app=egress-proxy
```

### 3. Cluster Ingress Testing

**Method A: External Access to Services**
```bash
# Access nginx app through Tailscale ingress
curl http://k8s-ingress.your-tailnet.ts.net
curl -I http://k8s-ingress.your-tailnet.ts.net

# Test from different Tailscale devices
ping k8s-ingress.your-tailnet.ts.net
```

**Method B: Service Discovery**
```bash
# Verify ingress proxy configuration
kubectl get configmap -n tailscale ingress-nginx-config -o yaml
kubectl logs -n tailscale deployment/ingress-proxy -c nginx-proxy
```

**Method C: Load Balancer Status**
```bash
# Check LoadBalancer service status
kubectl get service -n tailscale test-app-loadbalancer
kubectl describe service -n tailscale test-app-annotated
```

### 4. Subnet Router Testing

**Method A: Direct Pod Access**
```bash
# Get pod IPs and test direct access
kubectl get pods -n tailscale -o wide
POD_IP=$(kubectl get pod -n tailscale -l app=test-app -o jsonpath='{.items[0].status.podIP}')
curl http://$POD_IP

# From Tailscale device, access pod directly
curl http://10.0.1.22  # Replace with actual pod IP
```

**Method B: Service Network Access**
```bash
# Test service network access via Tailscale
kubectl get services -n tailscale -o wide
curl http://172.20.233.38  # Replace with actual service IP

# Verify advertised routes
kubectl exec -n tailscale deployment/subnet-router -- tailscale status
```

**Method C: Route Validation**
```bash
# Check subnet router logs and routes
kubectl logs -n tailscale deployment/subnet-router
kubectl exec -n tailscale deployment/subnet-router -- ip route show

# Verify in Tailscale admin console
# Visit: https://login.tailscale.com/admin/machines
# Confirm k8s-subnet-router shows advertised routes: 10.100.0.0/16
```

### Complete System Test
```bash
# Run comprehensive validation
kubectl get all -n tailscale
kubectl get pods -n tailscale -o wide

# Check all Tailscale connections
for pod in api-proxy egress-proxy subnet-router ingress-proxy; do
  echo "=== $pod Status ==="
  kubectl exec -n tailscale deployment/$pod -- tailscale status 2>/dev/null || echo "No tailscale command"
done
```

## 🎯 Quick Testing

Run the automated test suite:
```bash
# Test all use-cases from within cluster
./scripts/test-tailscale.sh

# Test connectivity from external Tailscale devices  
./scripts/validate-connectivity.sh

# Interactive demo of each use-case
./scripts/demo-use-cases.sh
```

## 🧹 Cleanup

```bash
# Use automated cleanup script
./scripts/cleanup.sh

# Or manual cleanup:
kubectl delete -f k8s-manifests/manual-tailscale-demos.yaml
kubectl delete -f k8s-manifests/tailscale-rbac.yaml
terraform destroy
```

## 📚 References

- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale OAuth](https://tailscale.com/kb/1215/oauth-clients)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)

## 📧 Tailnet Information

**Tailnet Address:** `your-email@domain.com` (replace with your actual Tailscale account)

---

Built with ❤️ for Tailscale infrastructure demonstration
