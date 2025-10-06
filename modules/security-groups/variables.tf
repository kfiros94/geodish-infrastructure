# modules/security-groups/variables.tf

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "geodish"
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC for internal communication rules"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

variable "enable_alb_ingress" {
  description = "Enable ALB Ingress Controller security group rules"
  type        = bool
  default     = true
}

variable "enable_cluster_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access EKS cluster endpoint"
  type        = list(string)
  default     = []
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
  default     = ["0.0.0.0/0"]
}

variable "node_group_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3a.medium"]
  validation {
    condition     = alltrue([for t in var.node_group_instance_types : can(regex("^[tm][0-9][a-z]*\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", t))])
    error_message = "Instance types must be valid EC2 instance types."
  }
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to EKS nodes"
  type        = list(string)
  default     = []
}

variable "worker_additional_security_groups" {
  description = "Additional security groups for worker nodes"
  type        = list(string)
  default     = []
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to security groups"
  type        = map(string)
  default     = {}
}

#==========================================
# Application-Specific Variables
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

variable "nginx_port" {
  description = "Port on which Nginx runs"
  type        = number
  default     = 80
}

variable "ssl_port" {
  description = "HTTPS/SSL port"
  type        = number
  default     = 443
}

#==========================================
# Load Balancer Variables
#==========================================

variable "alb_security_group_rules" {
  description = "Custom ALB security group rules"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from internet"
    },
    {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from internet"
    }
  ]
}

variable "enable_node_to_node_encryption" {
  description = "Enable encryption in transit between nodes"
  type        = bool
  default     = true
}
