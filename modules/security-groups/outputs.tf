# modules/security-groups/outputs.tf

#==========================================
# EKS Security Group Outputs
#==========================================

output "cluster_security_group_id" {
  description = "Security group ID for the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "cluster_security_group_arn" {
  description = "ARN of the EKS cluster security group"
  value       = aws_security_group.cluster.arn
}

output "node_group_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.node_group.id
}

output "node_group_security_group_arn" {
  description = "ARN of the EKS node group security group"
  value       = aws_security_group.node_group.arn
}

#==========================================
# Load Balancer Security Group Outputs
#==========================================

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = var.enable_alb_ingress ? aws_security_group.alb[0].id : null
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = var.enable_alb_ingress ? aws_security_group.alb[0].arn : null
}

#==========================================
# Database Security Group Outputs
#==========================================

output "database_security_group_id" {
  description = "Security group ID for MongoDB database"
  value       = aws_security_group.database.id
}

output "database_security_group_arn" {
  description = "ARN of the database security group"
  value       = aws_security_group.database.arn
}

#==========================================
# Additional Security Group Outputs
#==========================================

output "cache_security_group_id" {
  description = "Security group ID for cache layer (Redis/ElastiCache)"
  value       = aws_security_group.cache.id
}

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

#==========================================
# EKS-Specific Integration Outputs
#==========================================

output "eks_cluster_additional_security_group_ids" {
  description = "Additional security group IDs to attach to EKS cluster"
  value       = [aws_security_group.cluster.id]
}

output "eks_node_group_security_group_ids" {
  description = "Security group IDs for EKS node groups"
  value = concat(
    [aws_security_group.node_group.id],
    var.additional_security_group_ids
  )
}

output "eks_fargate_pod_execution_security_group_ids" {
  description = "Security group IDs for Fargate pod execution (if using Fargate)"
  value       = [aws_security_group.node_group.id]
}

#==========================================
# Application Integration Outputs
#==========================================

output "app_security_group_ids" {
  description = "Security group IDs for application deployment"
  value = {
    cluster          = aws_security_group.cluster.id
    nodes           = aws_security_group.node_group.id
    database        = aws_security_group.database.id
    load_balancer   = var.enable_alb_ingress ? aws_security_group.alb[0].id : null
    cache           = aws_security_group.cache.id
    bastion         = aws_security_group.bastion.id
    vpc_endpoints   = aws_security_group.vpc_endpoints.id
  }
}

#==========================================
# Security Group Rules Summary
#==========================================

output "security_group_rules_summary" {
  description = "Summary of security group rules for documentation"
  value = {
    cluster_rules = {
      ingress_ports = ["443"]
      egress_ports  = ["all"]
      description   = "EKS cluster control plane communication"
    }
    node_rules = {
      ingress_ports = ["1025-65535", "443", "all_from_self"]
      egress_ports  = ["all"]
      description   = "EKS worker nodes communication"
    }
    alb_rules = {
      ingress_ports = var.enable_alb_ingress ? ["80", "443"] : []
      egress_ports  = var.enable_alb_ingress ? [tostring(var.app_port)] : []
      description   = "Application Load Balancer public access"
    }
    database_rules = {
      ingress_ports = [tostring(var.mongodb_port)]
      egress_ports  = ["all"]
      description   = "MongoDB database access from applications only"
    }
  }
}

#==========================================
# Networking Information
#==========================================

output "cluster_name" {
  description = "Name of the EKS cluster these security groups support"
  value       = local.cluster_name
}

output "vpc_id" {
  description = "VPC ID where security groups are deployed"
  value       = var.vpc_id
}

output "name_prefix" {
  description = "Name prefix used for security group naming"
  value       = local.name_prefix
}

#==========================================
# Port Configuration Outputs
#==========================================

output "application_ports" {
  description = "Port configuration for applications"
  value = {
    app_port     = var.app_port
    mongodb_port = var.mongodb_port
    nginx_port   = var.nginx_port
    ssl_port     = var.ssl_port
    redis_port   = 6379
    ssh_port     = 22
  }
}

#==========================================
# Compliance and Security Outputs
#==========================================

output "security_compliance_info" {
  description = "Security compliance information"
  value = {
    private_nodes        = "EKS nodes deployed in private subnets"
    database_isolation   = "Database accessible only from application nodes"
    load_balancer_type   = var.enable_alb_ingress ? "Public ALB with security groups" : "No public load balancer"
    cluster_endpoint     = var.cluster_endpoint_public_access ? "Public with restricted CIDR" : "Private only"
    encryption_transit   = var.enable_node_to_node_encryption ? "Enabled" : "Disabled"
  }
}

#==========================================
# Monitoring and Logging Integration
#==========================================

output "cloudwatch_log_groups_access" {
  description = "Security groups that need CloudWatch Logs access"
  value = [
    aws_security_group.cluster.id,
    aws_security_group.node_group.id
  ]
}

output "prometheus_monitoring_access" {
  description = "Security groups for Prometheus monitoring access"
  value = [
    aws_security_group.node_group.id
  ]
}

#==========================================
# Tagging Outputs
#==========================================

output "common_tags" {
  description = "Common tags applied to all security groups"
  value       = local.common_tags
}

#==========================================
# Complete Security Groups Map
#==========================================

output "all_security_groups" {
  description = "Map of all created security groups"
  value = {
    cluster       = {
      id   = aws_security_group.cluster.id
      name = aws_security_group.cluster.name
      arn  = aws_security_group.cluster.arn
    }
    node_group    = {
      id   = aws_security_group.node_group.id
      name = aws_security_group.node_group.name
      arn  = aws_security_group.node_group.arn
    }
    alb           = var.enable_alb_ingress ? {
      id   = aws_security_group.alb[0].id
      name = aws_security_group.alb[0].name
      arn  = aws_security_group.alb[0].arn
    } : null
    database      = {
      id   = aws_security_group.database.id
      name = aws_security_group.database.name
      arn  = aws_security_group.database.arn
    }
    cache         = {
      id   = aws_security_group.cache.id
      name = aws_security_group.cache.name
      arn  = aws_security_group.cache.arn
    }
    bastion       = {
      id   = aws_security_group.bastion.id
      name = aws_security_group.bastion.name
      arn  = aws_security_group.bastion.arn
    }
    vpc_endpoints = {
      id   = aws_security_group.vpc_endpoints.id
      name = aws_security_group.vpc_endpoints.name
      arn  = aws_security_group.vpc_endpoints.arn
    }
  }
}
