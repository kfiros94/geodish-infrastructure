# modules/argocd/variables.tf

variable "argocd_namespace" {
  description = "Namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "app_namespace" {
  description = "Namespace for the application"
  type        = string
  default     = "devops-app"
}

variable "argocd_chart_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD server"
  type        = string
  default     = "argocd.local"
}

variable "git_repo_url" {
  description = "Git repository URL for GitOps"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag to sync"
  type        = string
  default     = "HEAD"
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
  default     = "geodish-user"
}

variable "mongodb_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB database name"
  type        = string
  default     = "geodish"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}