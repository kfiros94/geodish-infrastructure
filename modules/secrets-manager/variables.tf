# modules/secrets-manager/variables.tf

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "mongodb_password" {
  description = "MongoDB password to store in Secrets Manager"
  type        = string
  sensitive   = true
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "devops-app"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "geodish-secrets-sa"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}