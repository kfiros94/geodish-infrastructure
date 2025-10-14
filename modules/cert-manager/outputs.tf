# modules/cert-manager/outputs.tf

output "namespace" {
  description = "cert-manager namespace"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "letsencrypt_staging_issuer" {
  description = "Name of Let's Encrypt staging ClusterIssuer"
  value       = "letsencrypt-staging"
}

output "letsencrypt_prod_issuer" {
  description = "Name of Let's Encrypt production ClusterIssuer"
  value       = "letsencrypt-prod"
}