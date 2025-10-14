# environments/dev/variables.tf

#==========================================
# Basic Configuration Variables
#==========================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format like 'us-west-2' or 'ap-south-1'."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "geodish"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

#==========================================
# Network Configuration Variables
#==========================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (for EKS worker nodes)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required for EKS."
  }
}

#==========================================
# EKS Cluster Configuration
#==========================================

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

#==========================================
# EKS Node Group Configuration
# Requirements: Max 3 nodes (t3a.medium), start with 2
#==========================================

variable "node_group_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3a.medium"]
  validation {
    condition     = alltrue([for t in var.node_group_instance_types : can(regex("^[tm][0-9][a-z]*\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", t))])
    error_message = "Instance types must be valid EC2 instance types."
  }
}

variable "node_group_desired_capacity" {
  description = "Desired number of worker nodes (start with 2 for app + database)"
  type        = number
  default     = 3  # ← Change from 2 to 3
  validation {
    condition     = var.node_group_desired_capacity >= 1 && var.node_group_desired_capacity <= 3
    error_message = "Desired capacity must be between 1 and 3 nodes as per requirements."
  }
}
variable "node_group_max_capacity" {
  description = "Maximum number of worker nodes (max 3 as per requirements)"
  type        = number
  default     = 3
  validation {
    condition     = var.node_group_max_capacity >= 1 && var.node_group_max_capacity <= 3
    error_message = "Maximum capacity must be between 1 and 3 nodes as per requirements."
  }
}

variable "node_group_min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.node_group_min_capacity >= 1 && var.node_group_min_capacity <= 3
    error_message = "Minimum capacity must be between 1 and 3 nodes."
  }
}

variable "node_group_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
  validation {
    condition     = var.node_group_disk_size >= 20 && var.node_group_disk_size <= 100
    error_message = "Disk size must be between 20GB and 100GB."
  }
}

#==========================================
# Application Configuration
#==========================================

variable "app_port" {
  description = "Port on which the GeoDish application runs"
  type        = number
  default     = 5000
  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "Application port must be between 1 and 65535."
  }
}

variable "mongodb_port" {
  description = "Port on which MongoDB runs"
  type        = number
  default     = 27017
}

#==========================================
# Security Configuration
#==========================================

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for external access (bastion, etc.)"
  type        = list(string)
  default     = []  # Empty for security - add your IP if needed
}

#==========================================
# Logging Configuration
#==========================================

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  validation {
    condition = alltrue([
      for log_type in var.cluster_enabled_log_types : 
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be from: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cloudwatch_log_group_retention" {
  description = "Number of days to retain EKS cluster logs"
  type        = number
  default     = 7  # Short retention for dev to save costs
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_group_retention)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

#==========================================
# Feature Flags
#==========================================

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager access for worker nodes"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs access for cluster and nodes"
  type        = bool
  default     = true
}

variable "enable_ecr_access" {
  description = "Enable ECR access for pulling GeoDish container images"
  type        = bool
  default     = true
}

variable "enable_alb_ingress_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver for persistent volumes (needed for MongoDB)"
  type        = bool
  default     = true
}

#==========================================
# Development Environment Specific
#==========================================

variable "cost_optimization" {
  description = "Enable cost optimization features for development"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = false  # Disable initially to save costs
}

variable "enable_logging_stack" {
  description = "Enable logging stack (EFK)"
  type        = bool
  default     = false  # Disable initially to save costs
}

#==========================================
# GeoDish Specific Configuration
#==========================================

variable "geodish_ecr_repository_uri" {
  description = "ECR repository URI for GeoDish application"
  type        = string
  default     = "893692751288.dkr.ecr.ap-south-1.amazonaws.com/geodish-app"
}

variable "geodish_app_version" {
  description = "Version/tag of GeoDish application to deploy"
  type        = string
  default     = "latest"
}

#==========================================
# Backup and Disaster Recovery
#==========================================

variable "enable_backup" {
  description = "Enable backup for persistent volumes"
  type        = bool
  default     = false  # Disable in dev to save costs
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

#==========================================
# Additional Tags
#==========================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    CostCenter  = "Engineering"
    Team        = "DevOps"
    Purpose     = "Development"
    AutoShutdown = "true"
  }
}
#==========================================
# MongoDB Credentials
#==========================================

variable "mongodb_password" {
  description = "MongoDB password (set via TF_VAR_mongodb_password environment variable)"
  type        = string
  sensitive   = true
}
#==========================================
# ArgoCD Configuration
#==========================================

variable "argocd_chart_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD server"
  type        = string
  default     = "argocd.local"
}

variable "git_repo_url" {
  description = "Git repository URL for GitOps"
  type        = string
  default     = "https://github.com/kfiros94/geodish-gitops.git"
}

variable "git_target_revision" {
  description = "Git branch/tag to sync"
  type        = string
  default     = "HEAD"
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
  default     = "geodish-user"
}

variable "mongodb_database" {
  description = "MongoDB database name"
  type        = string
  default     = "geodish"
}

#==========================================
# Monitoring Configuration
#==========================================

variable "grafana_admin_password" {
  description = "Admin password for Grafana UI"
  type        = string
  default     = "GeoDishGrafana123!"
  sensitive   = true
}