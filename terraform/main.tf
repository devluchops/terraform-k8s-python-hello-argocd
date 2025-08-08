# =============================================================================
# AWS EKS CLUSTER WITH VPC AND ECR
# =============================================================================

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# EKS Module
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  # Ensure core add-ons are installed (per docs) and VPC CNI before compute
  addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-nodes"

      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_capacity
      max_size     = var.node_max_capacity
      desired_size = var.node_desired_capacity

      disk_size = 20
      disk_type = "gp3"

      # Force update to ensure clean state
      force_update_version = true

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      update_config = {
        max_unavailable_percentage = 50
      }

      tags = {
        Name = "${var.cluster_name}-nodes"
      }
    }
  }

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = var.cluster_name
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Note: Application Load Balancer (Ingress) will be managed by ArgoCD
# along with the application deployment and service

# ArgoCD
resource "helm_release" "argocd" {
  provider = helm.eks
  
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  create_namespace = true
  wait             = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        extraArgs = ["--insecure"]
      }
    })
  ]

  depends_on = [module.eks]
}

# Note: ArgoCD Application will be created manually after deployment
# This avoids the circular dependency issue with kubernetes_manifest
# Use the argocd-application.yaml file to create the application

# =============================================================================
# CLUSTER COMPONENTS
# =============================================================================

# Note: cert-manager will be managed by ArgoCD

# External Secrets Operator IAM Role
module "external_secrets" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.project_name}-external-secrets"

  attach_external_secrets_policy = true

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = {
    Name = "${var.project_name}-external-secrets-role"
  }
}

# Note: External Secrets will be managed by ArgoCD

# Note: ClusterSecretStore for AWS Secrets Manager will be managed by ArgoCD or applied post-bootstrap
# to avoid race conditions with the Kubernetes API during cluster creation.

# IAM Role for AWS Load Balancer Controller (IRSA)
module "alb_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.project_name}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "${var.project_name}-alb-controller-role"
  }
}