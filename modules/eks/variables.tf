# modules/eks/variables.tf

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

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

#==========================================
# Network Configuration
#==========================================

variable "vpc_id" {
  description = "ID of the VPC where EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where EKS cluster will be placed (both public and private)"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for EKS cluster."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS node groups (security best practice)"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for node groups."
  }
}

#==========================================
# Security Configuration
#==========================================

variable "cluster_security_group_ids" {
  description = "List of security group IDs for the EKS cluster"
  type        = list(string)
  default     = []
}

variable "node_security_group_ids" {
  description = "List of security group IDs for EKS worker nodes"
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

#==========================================
# IAM Configuration
#==========================================

variable "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  type        = string
}

#==========================================
# Node Group Configuration
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
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.node_group_desired_capacity >= 1 && var.node_group_desired_capacity <= 3
    error_message = "Desired capacity must be between 1 and 3 nodes as per requirements."
  }
}

variable "node_group_max_capacity" {
  description = "Maximum number of worker nodes"
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

variable "node_group_ami_type" {
  description = "Type of Amazon Machine Image (AMI) for worker nodes"
  type        = string
  default     = "AL2_x86_64"
  validation {
    condition     = contains(["AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64"], var.node_group_ami_type)
    error_message = "AMI type must be AL2_x86_64, AL2_x86_64_GPU, or AL2_ARM_64."
  }
}

variable "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_group_capacity_type)
    error_message = "Capacity type must be ON_DEMAND or SPOT."
  }
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
  default     = 7
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_group_retention)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

#==========================================
# Add-ons Configuration
#==========================================

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler add-on"
  type        = bool
  default     = false
}

variable "enable_alb_ingress_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver for persistent volumes"
  type        = bool
  default     = true
}

#==========================================
# Additional Configuration
#==========================================

variable "tags" {
  description = "Additional tags to apply to EKS resources"
  type        = map(string)
  default     = {}
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap"
  type        = list(string)
  default     = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
