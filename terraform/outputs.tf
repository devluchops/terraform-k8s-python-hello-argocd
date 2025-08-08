# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

# ECR Outputs
output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

# Application Outputs (managed by ArgoCD)
output "app_namespace" {
  description = "Application namespace (managed by ArgoCD)"
  value       = "demo"
}

output "app_service_name" {
  description = "Application service name (managed by ArgoCD)"
  value       = "python-hello-world-service"
}

output "app_load_balancer_hostname" {
  description = "Command to get Application Load Balancer hostname"
  value       = "kubectl get ingress python-hello-world-ingress -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

# ArgoCD Outputs
output "argocd_server_hostname" {
  description = "ArgoCD server hostname"
  value       = "Run: kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

# Useful Commands
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
}

output "build_and_push_commands" {
  description = "Commands to build and push Docker image"
  value = [
    "docker build -t ${aws_ecr_repository.app.repository_url}:latest ./app",
    "docker push ${aws_ecr_repository.app.repository_url}:latest"
  ]
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Next Steps
output "next_steps" {
  description = "Next steps after deployment"
  value = [
    "1. Configure kubectl: ${local.configure_kubectl_command}",
    "2. Build and push image: Run the build_and_push_commands",
    "3. Get app URL: kubectl get ingress python-hello-world-ingress -n demo",
    "4. Get ArgoCD URL: kubectl get svc argocd-server -n argocd",
    "5. Get ArgoCD password: ${local.argocd_password_command}",
    "6. Update ECR image URL in k8s/overlays/dev/kustomization.yaml"
  ]
}

# External Secrets Outputs
output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets (IRSA)"
  value       = module.external_secrets.iam_role_arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (IRSA)"
  value       = module.alb_controller_irsa.iam_role_arn
}

# Local values for reuse
locals {
  configure_kubectl_command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  argocd_password_command   = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}