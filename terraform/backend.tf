# =============================================================================
# Terraform Backend Configuration
# =============================================================================

terraform {
  backend "s3" {
    # These values will be provided via backend config file or CLI
    # bucket         = "your-terraform-state-bucket"
    # key            = "gitops-demo/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
  }
}