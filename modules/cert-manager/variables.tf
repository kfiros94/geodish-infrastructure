# modules/cert-manager/variables.tf

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.13.2"
}

variable "acme_email" {
  description = "Email address for ACME registration (Let's Encrypt)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}