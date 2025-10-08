# modules/ebs-csi/variables.tf

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "addon_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
