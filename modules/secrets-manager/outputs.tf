# modules/secrets-manager/outputs.tf

output "secret_arn" {
  description = "ARN of the MongoDB password secret"
  value       = aws_secretsmanager_secret.mongodb_password.arn
}

output "secret_name" {
  description = "Name of the MongoDB password secret"
  value       = aws_secretsmanager_secret.mongodb_password.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for secrets access"
  value       = aws_iam_role.secrets_service_account.arn
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account.secrets.metadata[0].name
}

output "service_account_namespace" {
  description = "Namespace of the Kubernetes service account"
  value       = kubernetes_service_account.secrets.metadata[0].namespace
}

output "access_instructions" {
  description = "Instructions for accessing the secret"
  value = {
    secret_name    = aws_secretsmanager_secret.mongodb_password.name
    region         = data.aws_region.current.name
    cli_command    = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_password.name} --region ${data.aws_region.current.name}"
    service_account = var.service_account_name
    namespace      = var.namespace
  }
}