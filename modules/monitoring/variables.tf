# modules/monitoring/variables.tf

variable "monitoring_namespace" {
  description = "Namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "app_namespace" {
  description = "Namespace where application is deployed"
  type        = string
  default     = "devops-app"
}

variable "prometheus_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.5.0"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "enable_alertmanager" {
  description = "Enable AlertManager for alerts"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 7
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "5Gi"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}