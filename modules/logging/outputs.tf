# modules/logging/outputs.tf

output "logging_namespace" {
  description = "Logging namespace name"
  value       = kubernetes_namespace.logging.metadata[0].name
}

output "elasticsearch_service" {
  description = "Elasticsearch service name"
  value       = "elasticsearch-master"
}

output "kibana_service" {
  description = "Kibana service name"
  value       = "kibana-kibana"
}

output "kibana_url_command" {
  description = "Command to get Kibana LoadBalancer URL"
  value       = "kubectl get svc kibana-kibana -n ${var.logging_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "elasticsearch_url" {
  description = "Elasticsearch internal URL"
  value       = "http://elasticsearch-master.${var.logging_namespace}.svc.cluster.local:9200"
}

output "access_instructions" {
  description = "Instructions to access logging services"
  value = {
    kibana_url = "Get URL: kubectl get svc kibana-kibana -n ${var.logging_namespace}"
    kibana_port = "5601"
    elasticsearch_internal = "http://elasticsearch-master.${var.logging_namespace}.svc.cluster.local:9200"
    view_logs_command = "Open Kibana UI and navigate to: Discover → Create index pattern → fluentd-*"
  }
}

output "log_retention_days" {
  description = "Log retention period in days"
  value       = var.retention_days
}