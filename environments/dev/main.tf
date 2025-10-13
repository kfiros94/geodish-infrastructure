# environments/dev/main.tf

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Backend configuration - S3 state management
  backend "s3" {
    bucket         = "geodish-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "geodish-terraform-locks"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Configure kubectl Provider
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

# Data source for EKS cluster auth
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Local values for consistent naming and tagging
locals {
  project     = var.project_name
  environment = var.environment
  
  common_tags = merge(var.additional_tags, {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  })
}

#==========================================
# VPC Module
#==========================================
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = local.project
  environment  = local.environment
  
  vpc_cidr               = var.vpc_cidr
  availability_zones     = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs    = var.public_subnet_cidrs  
  private_subnet_cidrs   = var.private_subnet_cidrs
  
  enable_nat_gateway   = true
  single_nat_gateway   = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = local.common_tags
}

#==========================================
# Security Groups Module
#==========================================
module "security_groups" {
  source = "../../modules/security-groups"
  
  project_name = local.project         
  environment  = local.environment
  cluster_name = "${local.project}-${local.environment}-eks"
  
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
  
  cluster_version = var.cluster_version
  
  tags = local.common_tags              
  
  depends_on = [module.vpc]
}

#==========================================
# IAM Module
#==========================================
module "iam" {
  source = "../../modules/iam"
  
  project_name  = local.project
  environment   = local.environment
  cluster_name  = "${local.project}-${local.environment}-eks"
  
  enable_irsa           = var.enable_irsa
  enable_ssm_access     = var.enable_ssm_access
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  enable_ecr_access     = var.enable_ecr_access
  
  depends_on = [module.vpc]
}

#==========================================
# EKS Module
#==========================================
module "eks" {
  source = "../../modules/eks"
  
  project_name = local.project
  environment  = local.environment
  
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  cluster_security_group_ids = [module.security_groups.cluster_security_group_id]
  node_security_group_ids    = [module.security_groups.node_group_security_group_id]
  
  cluster_service_role_arn = module.iam.cluster_service_role_arn
  node_group_role_arn     = module.iam.node_group_role_arn
  
  node_group_instance_types    = var.node_group_instance_types
  node_group_desired_capacity  = var.node_group_desired_capacity
  node_group_max_capacity      = var.node_group_max_capacity
  node_group_min_capacity      = var.node_group_min_capacity
  node_group_disk_size         = var.node_group_disk_size
  node_group_capacity_type     = "ON_DEMAND"
  
  cluster_version = var.cluster_version
  
  enable_irsa              = var.enable_irsa
  enable_ebs_csi_driver    = var.enable_ebs_csi_driver
  enable_cluster_autoscaler = false
  
  tags = local.common_tags
  
  depends_on = [module.vpc, module.security_groups, module.iam]
}

#==========================================
# EBS CSI Module
#==========================================
module "ebs_csi" {
  source = "../../modules/ebs-csi"
  
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  
  addon_version = null
  tags         = local.common_tags
  
  depends_on = [module.eks]
}

#==========================================
# NGINX Ingress Controller
#==========================================
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"
  namespace  = "ingress-nginx"
  
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
        }
        metrics = {
          enabled = true
        }
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [module.eks, module.ebs_csi]
}

#==========================================
# ArgoCD Module - Automated GitOps
#==========================================
module "argocd" {
  source = "../../modules/argocd"
  
  argocd_namespace      = "argocd"
  app_namespace         = "devops-app"
  argocd_chart_version  = "5.51.6"
  argocd_domain         = "argocd.local"
  
  git_repo_url         = "https://github.com/kfiros94/geodish-gitops.git"
  git_target_revision  = "HEAD"
  
  mongodb_username = "geodish-user"
  mongodb_password = var.mongodb_password
  mongodb_database = "geodish"
  
  tags = local.common_tags
  
  depends_on = [module.eks, module.ebs_csi, helm_release.nginx_ingress]
}