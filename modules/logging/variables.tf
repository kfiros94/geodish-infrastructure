# modules/logging/variables.tf

variable "logging_namespace" {
  description = "Namespace for logging stack"
  type        = string
  default     = "logging"
}

variable "elasticsearch_replicas" {
  description = "Number of Elasticsearch replicas"
  type        = number
  default     = 1
}

variable "elasticsearch_storage_size" {
  description = "Storage size for Elasticsearch"
  type        = string
  default     = "20Gi"
}

variable "elasticsearch_memory_limit" {
  description = "Memory limit for Elasticsearch"
  type        = string
  default     = "2Gi"
}

variable "elasticsearch_memory_request" {
  description = "Memory request for Elasticsearch"
  type        = string
  default     = "1Gi"
}

variable "fluentd_memory_limit" {
  description = "Memory limit for Fluentd"
  type        = string
  default     = "512Mi"
}

variable "kibana_replicas" {
  description = "Number of Kibana replicas"
  type        = number
  default     = 1
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}