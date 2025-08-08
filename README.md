# AWS EKS Terraform Python Hello World with ArgoCD

Production-ready GitOps setup with AWS EKS, Terraform, and ArgoCD.

**Infrastructure**: `gitops-demo` cluster (Kubernetes 1.31)  
**Application**: `python-hello-world` app in `demo` namespace with demo endpoints

## Architecture

```
AWS Account
├── VPC (10.0.0.0/16)
│   ├── Public Subnets (NAT Gateway, ALB)
│   └── Private Subnets (EKS Cluster, 2 x t3.small nodes)
├── ECR (python-hello-world:latest)
└── S3 + DynamoDB (Terraform state)
```

## Project Structure

```
terraform-k8s-python-hello-argocd/
├── app/                    # Python Flask application
├── terraform/              # Infrastructure (VPC, EKS, ECR, ArgoCD)
├── k8s/                   # Kubernetes manifests (GitOps)
│   ├── base/              # Base Kustomize configuration
│   └── overlays/          # Environment-specific overlays
│       ├── dev/           # Development (2 replicas, :latest)
│       └── prod/          # Production (3 replicas, :stable)

├── argocd-application.yaml # ArgoCD Application definition
└── Makefile               # Automation
```

## Quick Start

### 1. Configure AWS
```bash
aws configure
```

### 2. Complete Setup
```bash
make setup
```

This will:
1. Create S3 bucket + DynamoDB table for Terraform state
2. Deploy VPC, EKS cluster, ECR repository
3. Install ArgoCD
4. Update Kustomize with ECR URLs
5. Build and push Docker image
6. Create ArgoCD Application

### 3. Access Application
```bash
make get-app-url
# Visit the URL (wait 5-10 minutes for ALB)
# Available endpoints: /, /demo, /k8s, /metrics, /health
```

### 4. Access ArgoCD
```bash
make get-argocd-url
make get-argocd-password
# Username: admin, Password: from command above
```

## GitOps Workflow

**Infrastructure (Terraform)**: VPC, EKS, ECR, ArgoCD  
**Applications (ArgoCD + Kustomize)**: Kubernetes manifests, deployments

1. **Infrastructure changes**: Modify Terraform → `make deploy`
2. **Application changes**: Modify `k8s/` → ArgoCD auto-syncs
3. **New images**: Build → Push → Update Kustomize → ArgoCD deploys

## Commands

```bash
# Infrastructure
make init               # Setup backend + initialize
make plan               # Plan changes
make deploy             # Deploy infrastructure
make destroy            # Destroy everything

# Application
make build-and-push     # Build and push image
make get-app-url        # Get application URL

# ArgoCD
make get-argocd-url     # Get ArgoCD URL
make get-argocd-password # Get ArgoCD password

# Complete
make setup              # Full setup
make status             # Check cluster status
```

## Costs

**Estimated monthly cost**: ~$215 (us-east-1)
- EKS Control Plane: ~$73
- 2 x t3.small nodes: ~$60
- NAT Gateway: ~$45
- Load Balancers: ~$36
- ECR: ~$1

**⚠️ Run `make destroy` when not in use!**

## Application Endpoints

- `/` - Hello world with pod info
- `/demo` - Interactive web interface
- `/k8s` - Kubernetes environment details
- `/metrics` - Application metrics and uptime
- `/health` - Health check endpoint
- `/load/<seconds>` - CPU load simulation (max 30s)
- `/slow` - Slow response test (3s delay)
- `/fail` - Force 500 error for testing

## Features

- ✅ **Production VPC**: Multi-AZ, private subnets, NAT Gateway
- ✅ **EKS Cluster**: Managed Kubernetes with 2 worker nodes
- ✅ **Remote State**: S3 + DynamoDB for Terraform state
- ✅ **GitOps**: ArgoCD with Kustomize overlays
- ✅ **Container Registry**: Private ECR
- ✅ **Load Balancing**: ALB for app, NLB for ArgoCD
- ✅ **Demo App**: Multiple endpoints for testing and demos
- ✅ **Automation**: Complete setup with one command