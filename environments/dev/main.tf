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
  }

  # Backend configuration - S3 state management
  backend "s3" {
    bucket         = "geodish-terraform-state-dev"  # You'll need to create this bucket
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "geodish-terraform-locks"      # For state locking
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

# Local values for consistent tagging
locals {
  environment = "dev"
  project     = "geodish"
  
  common_tags = {
    Project     = local.project
    Environment = local.environment
    Owner       = "DevOps-Bootcamp"
    ManagedBy   = "Terraform"
    Repository  = "geodish-infrastructure"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
  
  # Cluster configuration
  cluster_name = "${local.project}-${local.environment}-eks"
}

#==========================================
# DATA SOURCES
#==========================================

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

data "aws_caller_identity" "current" {}

#==========================================
# VPC MODULE
#==========================================

module "vpc" {
  source = "../../modules/vpc"
  
  # Basic configuration
  project_name = local.project
  environment  = local.environment
  
  # Network configuration
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  # Cost optimization for dev environment
  single_nat_gateway = true  # Single NAT Gateway to reduce costs
  
  tags = local.common_tags
}

#==========================================
# SECURITY GROUPS MODULE
#==========================================

module "security_groups" {
  source = "../../modules/security-groups"
  
  # Basic configuration
  project_name = local.project
  environment  = local.environment
  
  # Network configuration
  vpc_id    = module.vpc.vpc_id
  vpc_cidr  = module.vpc.vpc_cidr_block
  
  # EKS configuration
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  
  # Application configuration
  app_port     = var.app_port
  mongodb_port = var.mongodb_port
  
  # Security configuration
  allowed_cidr_blocks                   = var.allowed_cidr_blocks
  cluster_endpoint_public_access_cidrs  = var.cluster_endpoint_public_access_cidrs
  
  tags = local.common_tags
}

#==========================================
# IAM MODULE
#==========================================

module "iam" {
  source = "../../modules/iam"
  
  # Basic configuration
  project_name = local.project
  environment  = local.environment
  
  # EKS configuration
  cluster_name = local.cluster_name
  
  # Feature flags
  enable_irsa            = var.enable_irsa
  enable_ssm_access      = var.enable_ssm_access
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  enable_ecr_access      = var.enable_ecr_access
  
  # This will be updated after EKS cluster creation
  oidc_provider_arn = "" # Will be set by EKS module
  
  tags = local.common_tags
}

#==========================================
# EKS MODULE
#==========================================

module "eks" {
  source = "../../modules/eks"
  
  # Basic configuration
  project_name    = local.project
  environment     = local.environment
  cluster_version = var.cluster_version
  
  # Network configuration
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.eks_cluster_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  # Security configuration
  cluster_security_group_ids = [module.security_groups.cluster_security_group_id]
  node_security_group_ids    = [module.security_groups.node_group_security_group_id]
  
  # Endpoint access configuration
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  
  # IAM configuration
  cluster_service_role_arn = module.iam.cluster_service_role_arn
  node_group_role_arn      = module.iam.node_group_role_arn
  
  # Node group configuration - Start with 2 nodes as required
  node_group_desired_capacity = var.node_group_desired_capacity
  node_group_max_capacity     = var.node_group_max_capacity
  node_group_min_capacity     = var.node_group_min_capacity
  node_group_instance_types   = var.node_group_instance_types
  node_group_disk_size        = var.node_group_disk_size
  
  # Logging configuration
  cluster_enabled_log_types       = var.cluster_enabled_log_types
  cloudwatch_log_group_retention  = var.cloudwatch_log_group_retention
  
  # Feature flags
  enable_irsa                    = var.enable_irsa
  enable_alb_ingress_controller  = var.enable_alb_ingress_controller
  enable_ebs_csi_driver          = var.enable_ebs_csi_driver
  
  tags = local.common_tags
  
  depends_on = [
    module.vpc,
    module.security_groups,
    module.iam
  ]
}

#==========================================
# KUBERNETES PROVIDER CONFIGURATION
#==========================================

# Configure Kubernetes provider for post-deployment management
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region
      ]
    }
  }
}

#==========================================
# POST-DEPLOYMENT KUBERNETES RESOURCES
#==========================================

# Create namespace for GeoDish application
resource "kubernetes_namespace" "geodish_app" {
  metadata {
    name = "geodish-app"
    
    labels = {
      name        = "geodish-app"
      environment = local.environment
      project     = local.project
    }
  }
  
  depends_on = [module.eks]
}

# Create namespace for monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = {
      name        = "monitoring"
      environment = local.environment
      project     = local.project
    }
  }
  
  depends_on = [module.eks]
}

# Create namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    
    labels = {
      name        = "argocd"
      environment = local.environment
      project     = local.project
    }
  }
  
  depends_on = [module.eks]
}
