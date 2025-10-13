# modules/argocd/outputs.tf

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "app_namespace" {
  description = "Application namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "root_app_name" {
  description = "Root ArgoCD application name"
  value       = "geodish-root-app"
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}