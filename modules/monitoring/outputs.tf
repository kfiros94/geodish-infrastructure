# modules/monitoring/outputs.tf

output "monitoring_namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = "prometheus-kube-prometheus-prometheus"
}

output "grafana_service" {
  description = "Grafana service name"
  value       = "prometheus-grafana"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "grafana_url_command" {
  description = "Command to get Grafana LoadBalancer URL"
  value       = "kubectl get svc prometheus-grafana -n ${var.monitoring_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "prometheus_url_command" {
  description = "Command to access Prometheus UI"
  value       = "kubectl port-forward -n ${var.monitoring_namespace} svc/prometheus-kube-prometheus-prometheus 9090:9090"
}

output "access_instructions" {
  description = "Instructions to access monitoring services"
  value = {
    grafana_url      = "Get URL: kubectl get svc prometheus-grafana -n ${var.monitoring_namespace}"
    grafana_username = "admin"
    grafana_password = "Use: echo ${var.grafana_admin_password}"
    prometheus_port_forward = "kubectl port-forward -n ${var.monitoring_namespace} svc/prometheus-kube-prometheus-prometheus 9090:9090"
  }
}