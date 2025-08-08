# Simple EKS GitOps Setup

TERRAFORM_DIR = terraform
APP_DIR = app
AWS_REGION ?= us-east-1

# Optional tfvars support: pass TFVARS=<file> (relative to $(TERRAFORM_DIR)) or
# place a default terraform.tfvars inside $(TERRAFORM_DIR)
TFVARS ?=
TFVARS_ARG = $(if $(TFVARS),-var-file=$(TFVARS),$(if $(wildcard $(TERRAFORM_DIR)/terraform.tfvars),-var-file=terraform.tfvars,))

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: setup-bucket
setup-bucket: ## Create S3 bucket for Terraform state
	@echo "🪣 Creating S3 bucket for Terraform state..."
	@BUCKET_NAME="gitops-demo-terraform-state-2025"; \
	REGION="us-east-1"; \
	if aws s3 ls "s3://$$BUCKET_NAME" 2>/dev/null; then \
		echo "✅ S3 bucket $$BUCKET_NAME already exists"; \
	else \
		aws s3 mb "s3://$$BUCKET_NAME" --region "$$REGION"; \
		echo "✅ S3 bucket $$BUCKET_NAME created"; \
	fi; \
	aws s3api put-bucket-versioning --bucket "$$BUCKET_NAME" --versioning-configuration Status=Enabled; \
	aws s3api put-bucket-encryption --bucket "$$BUCKET_NAME" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'; \
	aws s3api put-public-access-block --bucket "$$BUCKET_NAME" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true; \
	echo "✅ S3 bucket setup complete!"

.PHONY: update-ecr
update-ecr: ## Update ECR URLs in Kustomize overlays
	@echo "📝 Updating ECR URLs in overlays..."
	@ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ACCOUNT_ID"); \
	REGION=$$(aws configure get region 2>/dev/null || echo "REGION"); \
	if [ "$$ACCOUNT_ID" = "ACCOUNT_ID" ] || [ "$$REGION" = "REGION" ]; then \
		echo "⚠️  AWS credentials not configured. Using placeholder values."; \
		ACCOUNT_ID="ACCOUNT_ID"; \
		REGION="REGION"; \
	else \
		echo "✅ Using AWS Account: $$ACCOUNT_ID, Region: $$REGION"; \
	fi; \
	ECR_URL="$${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com/python-hello-world"; \
	sed -i.bak "s|ACCOUNT_ID\.dkr\.ecr\.REGION\.amazonaws\.com/python-hello-world|$$ECR_URL|g" k8s/overlays/dev/kustomization.yaml; \
	sed -i.bak "s|ACCOUNT_ID\.dkr\.ecr\.REGION\.amazonaws\.com/python-hello-world|$$ECR_URL|g" k8s/overlays/prod/kustomization.yaml; \
	rm -f k8s/overlays/dev/kustomization.yaml.bak k8s/overlays/prod/kustomization.yaml.bak; \
	echo "✅ ECR URLs updated successfully!"

.PHONY: init
init: setup-bucket ## Initialize Terraform (creates S3 bucket if needed)
	@cd $(TERRAFORM_DIR) && terraform init -backend-config=backend-config.hcl

.PHONY: plan
plan: ## Plan deployment
	@cd $(TERRAFORM_DIR) && terraform plan $(TFVARS_ARG)

.PHONY: deploy
deploy: ## Deploy infrastructure
	@cd $(TERRAFORM_DIR) && terraform apply $(TFVARS_ARG) -auto-approve

.PHONY: destroy
destroy: ## Destroy ALL resources including S3 bucket
	@echo "🗑️  Destroying ALL resources..."
	@echo "⚠️  This will remove EVERYTHING including S3 bucket!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "🔄 Removing ArgoCD from Terraform state..."
	@cd $(TERRAFORM_DIR) && terraform state rm helm_release.argocd 2>/dev/null || true
	@echo "🗑️  Force deleting ECR repository with images..."
	@aws ecr delete-repository --repository-name python-hello-world --region $(AWS_REGION) --force 2>/dev/null || echo "ℹ️  ECR repository not found or already deleted"
	@echo "🔄 Destroying Terraform infrastructure..."
	@cd $(TERRAFORM_DIR) && terraform destroy $(TFVARS_ARG) -auto-approve -refresh=false
	@echo "🪣 Emptying and deleting S3 bucket..."
	@BUCKET_NAME="gitops-demo-terraform-state-2025"; \
	if aws s3 ls "s3://$$BUCKET_NAME" 2>/dev/null; then \
		echo "📦 Emptying bucket $$BUCKET_NAME..."; \
		aws s3 rm "s3://$$BUCKET_NAME" --recursive 2>/dev/null || true; \
		echo "🗑️  Deleting bucket $$BUCKET_NAME..."; \
		aws s3 rb "s3://$$BUCKET_NAME" --force 2>/dev/null || true; \
		echo "✅ S3 bucket deleted"; \
	else \
		echo "ℹ️  S3 bucket $$BUCKET_NAME not found"; \
	fi

	@echo "🧹 Cleaning up local files..."
	@rm -rf $(TERRAFORM_DIR)/.terraform 2>/dev/null || true
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl 2>/dev/null || true
	@echo "✅ Complete destruction finished!"
	@echo "🔍 Verifying cleanup..."
	@echo "EKS Clusters:" && aws eks list-clusters --region $(AWS_REGION) --query 'clusters' --output table || true
	@echo "Load Balancers:" && aws elbv2 describe-load-balancers --region $(AWS_REGION) --query 'LoadBalancers[].LoadBalancerName' --output table || true

.PHONY: kubectl
kubectl: ## Configure kubectl
	@CLUSTER_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw cluster_name); \
	aws eks update-kubeconfig --region $(AWS_REGION) --name $$CLUSTER_NAME

.PHONY: build
build: ## Build and push app
	@ECR_URL=$$(cd $(TERRAFORM_DIR) && terraform output -raw ecr_repository_url); \
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URL; \
	( docker buildx inspect multiarch-builder >/dev/null 2>&1 || docker buildx create --name multiarch-builder --use ); \
	docker buildx use multiarch-builder; \
	cd $(APP_DIR) && docker buildx build --platform linux/amd64 -t $$ECR_URL:latest --push .

.PHONY: app
app: ## Deploy ArgoCD application
	@kubectl apply -f argocd-application.yaml

.PHONY: urls
urls: ## Get service URLs
	@echo "ArgoCD: http://$$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"