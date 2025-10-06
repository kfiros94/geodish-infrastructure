# modules/iam/outputs.tf

#==========================================
# EKS Cluster IAM Outputs
#==========================================

output "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = aws_iam_role.cluster_service_role.arn
}

output "cluster_service_role_name" {
  description = "Name of the EKS cluster service role"
  value       = aws_iam_role.cluster_service_role.name
}

#==========================================
# EKS Node Group IAM Outputs
#==========================================

output "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = aws_iam_role.node_group_role.arn
}

output "node_group_role_name" {
  description = "Name of the EKS node group role"
  value       = aws_iam_role.node_group_role.name
}

output "node_group_instance_profile_arn" {
  description = "ARN of the EKS node group instance profile"
  value       = aws_iam_instance_profile.node_group_profile.arn
}

output "node_group_instance_profile_name" {
  description = "Name of the EKS node group instance profile"
  value       = aws_iam_instance_profile.node_group_profile.name
}

#==========================================
# IRSA (IAM Roles for Service Accounts) Outputs
#==========================================

output "alb_controller_role_arn" {
  description = "ARN of the ALB Ingress Controller role (IRSA)"
  value       = var.enable_irsa ? aws_iam_role.alb_controller_role[0].arn : null
}

output "alb_controller_role_name" {
  description = "Name of the ALB Ingress Controller role (IRSA)"
  value       = var.enable_irsa ? aws_iam_role.alb_controller_role[0].name : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver role (IRSA)"
  value       = var.enable_irsa ? aws_iam_role.ebs_csi_driver_role[0].arn : null
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI Driver role (IRSA)"
  value       = var.enable_irsa ? aws_iam_role.ebs_csi_driver_role[0].name : null
}

#==========================================
# Policy Information Outputs
#==========================================

output "cluster_policies_attached" {
  description = "List of policies attached to the cluster role"
  value = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

output "node_group_policies_attached" {
  description = "List of policies attached to the node group role"
  value = concat([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ],
  var.enable_ssm_access ? ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] : [],
  var.additional_policy_arns
  )
}

#==========================================
# Service Account Annotations (for Kubernetes)
#==========================================

output "alb_controller_service_account_annotations" {
  description = "Annotations for ALB controller service account"
  value = var.enable_irsa ? {
    "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role[0].arn
  } : {}
}

output "ebs_csi_driver_service_account_annotations" {
  description = "Annotations for EBS CSI driver service account"
  value = var.enable_irsa ? {
    "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver_role[0].arn
  } : {}
}

#==========================================
# Complete IAM Configuration Summary
#==========================================

output "iam_roles_summary" {
  description = "Summary of all IAM roles created"
  value = {
    cluster_service_role = {
      name        = aws_iam_role.cluster_service_role.name
      arn         = aws_iam_role.cluster_service_role.arn
      description = "EKS cluster service role for control plane operations"
      policies    = ["AmazonEKSClusterPolicy"]
    }
    node_group_role = {
      name        = aws_iam_role.node_group_role.name
      arn         = aws_iam_role.node_group_role.arn
      description = "EKS worker node role for EC2 instances"
      policies = [
        "AmazonEKSWorkerNodePolicy",
        "AmazonEKS_CNI_Policy", 
        "AmazonEC2ContainerRegistryReadOnly"
      ]
    }
    alb_controller_role = var.enable_irsa ? {
      name        = aws_iam_role.alb_controller_role[0].name
      arn         = aws_iam_role.alb_controller_role[0].arn
      description = "IRSA role for AWS Load Balancer Controller"
      type        = "IRSA"
    } : null
    ebs_csi_driver_role = var.enable_irsa ? {
      name        = aws_iam_role.ebs_csi_driver_role[0].name
      arn         = aws_iam_role.ebs_csi_driver_role[0].arn
      description = "IRSA role for EBS CSI Driver"
      type        = "IRSA"
    } : null
  }
}

#==========================================
# Security and Compliance Outputs
#==========================================

output "security_features" {
  description = "Security features enabled in IAM configuration"
  value = {
    irsa_enabled            = var.enable_irsa
    ssm_access_enabled      = var.enable_ssm_access
    cloudwatch_logs_enabled = var.enable_cloudwatch_logs
    ecr_access_enabled      = var.enable_ecr_access
    additional_policies     = length(var.additional_policy_arns) > 0
  }
}

#==========================================
# Kubernetes Integration Outputs
#==========================================

output "kubernetes_service_accounts" {
  description = "Service account configurations for Kubernetes"
  value = var.enable_irsa ? {
    alb_controller = {
      namespace           = "kube-system"
      service_account     = "aws-load-balancer-controller"
      role_arn           = aws_iam_role.alb_controller_role[0].arn
      annotation_key     = "eks.amazonaws.com/role-arn"
    }
    ebs_csi_driver = {
      namespace           = "kube-system"
      service_account     = "ebs-csi-controller-sa"
      role_arn           = aws_iam_role.ebs_csi_driver_role[0].arn
      annotation_key     = "eks.amazonaws.com/role-arn"
    }
  } : {}
}

#==========================================
# Helm Chart Values Integration
#==========================================

output "helm_values" {
  description = "Values for Helm charts that need IAM roles"
  value = {
    aws_load_balancer_controller = var.enable_irsa ? {
      serviceAccount = {
        create      = true
        name        = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role[0].arn
        }
      }
    } : {}
    aws_ebs_csi_driver = var.enable_irsa ? {
      controller = {
        serviceAccount = {
          create      = true
          name        = "ebs-csi-controller-sa"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver_role[0].arn
          }
        }
      }
    } : {}
  }
}

#==========================================
# Environment and Tagging Outputs
#==========================================

output "common_tags" {
  description = "Common tags applied to all IAM resources"
  value       = local.common_tags
}

output "name_prefix" {
  description = "Name prefix used for IAM resource naming"
  value       = local.name_prefix
}

output "cluster_name" {
  description = "EKS cluster name these roles support"
  value       = var.cluster_name
}

#==========================================
# Monitoring and Logging Integration
#==========================================

output "cloudwatch_integration" {
  description = "CloudWatch integration configuration"
  value = var.enable_cloudwatch_logs ? {
    log_group_access    = "Enabled via node group role"
    metrics_access      = "Enabled via node group role"
    role_arn           = aws_iam_role.node_group_role.arn
  } : {
    log_group_access    = "Disabled"
    metrics_access      = "Disabled"
  }
}

#==========================================
# GeoDish Application Specific Outputs
#==========================================

output "geodish_application_roles" {
  description = "IAM roles specifically for GeoDish application"
  value = {
    ecr_access = {
      enabled   = var.enable_ecr_access
      role_arn  = aws_iam_role.node_group_role.arn
      description = "ECR access for pulling GeoDish container images"
    }
    node_management = {
      ssm_enabled = var.enable_ssm_access
      role_arn    = aws_iam_role.node_group_role.arn
      description = "Systems Manager access for node management"
    }
  }
}
