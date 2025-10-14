# modules/secrets-manager/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

#==========================================
# Data Sources
#==========================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#==========================================
# AWS Secrets Manager Secret
#==========================================
resource "aws_secretsmanager_secret" "mongodb_password" {
  name        = "${var.project_name}-${var.environment}-mongodb-password"
  description = "MongoDB password for GeoDish application"
  
  recovery_window_in_days = 0  # For dev - allows immediate deletion
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mongodb-password"
  })
}

resource "aws_secretsmanager_secret_version" "mongodb_password" {
  secret_id     = aws_secretsmanager_secret.mongodb_password.id
  secret_string = jsonencode({
    password = var.mongodb_password
  })
}

#==========================================
# IAM Policy for Secrets Access
#==========================================
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-${var.environment}-secrets-access"
  description = "Allow reading MongoDB password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.mongodb_password.arn
      }
    ]
  })

  tags = var.tags
}

#==========================================
# IAM Role for Service Account (IRSA)
#==========================================
resource "aws_iam_role" "secrets_service_account" {
  name = "${var.project_name}-${var.environment}-secrets-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.secrets_service_account.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

#==========================================
# Kubernetes Service Account
#==========================================
resource "kubernetes_service_account" "secrets" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.secrets_service_account.arn
    }
  }
}