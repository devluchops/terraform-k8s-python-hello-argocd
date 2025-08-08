# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "gitops-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gitops-demo"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 2
}

variable "node_min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

# Application Configuration
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "python-hello-world"
}

variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "demo"
}