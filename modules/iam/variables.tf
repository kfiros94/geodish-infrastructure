# modules/iam/variables.tf

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "geodish"
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA (will be created by EKS module)"
  type        = string
  default     = ""
}

variable "node_group_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3a.medium"]
}

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager access for worker nodes"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs access for cluster and nodes"
  type        = bool
  default     = true
}

variable "enable_ecr_access" {
  description = "Enable ECR access for pulling container images"
  type        = bool
  default     = true
}

variable "additional_policy_arns" {
  description = "Additional IAM policy ARNs to attach to worker nodes"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
