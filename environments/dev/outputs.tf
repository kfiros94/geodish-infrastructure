# environments/dev/outputs.tf

#==========================================
# VPC Outputs
#==========================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (where EKS nodes are deployed)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

#==========================================
# EKS Cluster Outputs
#==========================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate for kubectl configuration"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

#==========================================
# Node Group Outputs
#==========================================

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = module.eks.node_group_status
}

output "node_group_capacity_type" {
  description = "Capacity type of the EKS Node Group"
  value       = module.eks.node_group_capacity_type
}

output "node_group_instance_types" {
  description = "Instance types of the EKS Node Group"
  value       = module.eks.node_group_instance_types
}

#==========================================
# kubectl Configuration Command
#==========================================

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

#==========================================
# Application Deployment Information
#==========================================

output "geodish_deployment_info" {
  description = "Information for deploying GeoDish application"
  value = {
    cluster_name       = module.eks.cluster_name
    cluster_endpoint   = module.eks.cluster_endpoint
    ecr_repository     = var.geodish_ecr_repository_uri
    app_version        = var.geodish_app_version
    namespace          = "geodish-app"
    private_subnets    = module.vpc.private_subnet_ids
    security_verified  = "Nodes deployed in private subnets"
  }
}

#==========================================
# Security Summary
#==========================================

output "security_summary" {
  description = "Security configuration summary"
  value = {
    vpc_private_subnets     = length(module.vpc.private_subnet_ids)
    nodes_in_private        = true
    irsa_enabled           = var.enable_irsa
    cluster_logging        = length(var.cluster_enabled_log_types) > 0
    endpoint_access        = var.cluster_endpoint_public_access ? "Public + Private" : "Private Only"
    security_groups_count  = 7  # cluster, nodes, alb, database, cache, bastion, vpc-endpoints
  }
}

#==========================================
# Cost Information
#==========================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    eks_cluster          = "~72"      # EKS control plane
    ec2_instances        = "~60"      # 2 x t3a.medium
    nat_gateway          = "~45"      # Single NAT gateway
    ebs_volumes          = "~4"       # 2 x 20GB GP3
    cloudwatch_logs      = "~5"       # With 7-day retention
    data_transfer        = "~10"      # Estimated
    total_estimated      = "~196"     # USD per month
    note                = "Costs may vary based on usage"
  }
}

#==========================================
# Next Steps
#==========================================

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = [
    "1. Configure kubectl: ${local.configure_kubectl_command}",
    "2. Verify cluster: kubectl get nodes",
    "3. Create Helm charts for GeoDish application",
    "4. Deploy MongoDB using Helm",
    "5. Deploy GeoDish application",
    "6. Set up monitoring (Prometheus/Grafana)",
    "7. Configure ArgoCD for GitOps"
  ]
}

locals {
  configure_kubectl_command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
#==========================================
# ArgoCD Outputs
#==========================================

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = module.argocd.argocd_namespace
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = module.argocd.argocd_admin_password_command
}

output "app_namespace" {
  description = "Application namespace"
  value       = module.argocd.app_namespace
}

#==========================================
# Access Commands
#==========================================

output "access_instructions" {
  description = "How to access your deployed services"
  value = {
    step1_configure_kubectl = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
    step2_get_argocd_password = module.argocd.argocd_admin_password_command
    step3_get_argocd_url = "kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    step4_get_ingress_url = "kubectl get svc -n ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
    step5_check_apps = "kubectl get applications -n argocd"
    step6_check_pods = "kubectl get pods -n devops-app"
  }
}

#==========================================
# Deployment Status
#==========================================

output "deployment_status" {
  description = "Deployment status summary"
  value = {
    infrastructure_deployed = "✅ Complete"
    argocd_installed = "✅ Complete"
    mongodb_secret_created = "✅ Complete"
    gitops_enabled = "✅ Complete"
    auto_deployment = "✅ ArgoCD will deploy MongoDB and GeoDish automatically"
    manual_steps_required = "None - Everything is automated!"
  }
}