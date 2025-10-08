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

# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Local values for consistent tagging
locals {
  environment = "dev"
  project     = "geodish"
  
  common_tags = {
    Project     = local.project
    Environment = local.environment
    Owner       = "DevOps-Team"
    ManagedBy   = "Terraform"
  }
}

#==========================================
# VPC Module
#==========================================
module "vpc" {
  source = "../../modules/vpc"

  # Basic Configuration
  environment    = local.environment
  project        = local.project
  aws_region     = var.aws_region
  
  # VPC Configuration
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  # Feature Flags
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_nat_gateway   = var.enable_nat_gateway
  
  # Tags
  common_tags = local.common_tags
}

#==========================================
# Security Groups Module
#==========================================
module "security_groups" {
  source = "../../modules/security-groups"
  
  # Basic Configuration
  environment = local.environment
  project     = local.project
  
  # VPC Configuration
  vpc_id = module.vpc.vpc_id
  
  # CIDR Blocks for Security Rules
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  # External Access
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs
  allowed_https_cidrs = var.allowed_https_cidrs
  
  # Tags
  common_tags = local.common_tags
  
  depends_on = [module.vpc]
}

#==========================================
# IAM Module
#==========================================
module "iam" {
  source = "../../modules/iam"
  
  # Basic Configuration
  environment  = local.environment
  project      = local.project
  cluster_name = var.cluster_name
  
  # OIDC Configuration (will be updated after EKS cluster creation)
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_provider_url
  
  # Feature Flags
  enable_irsa           = var.enable_irsa
  enable_ssm_access     = var.enable_ssm_access
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  enable_ecr_access     = var.enable_ecr_access
  
  # Additional Policies (if any)
  additional_policy_arns = var.additional_policy_arns
  
  # Tags
  common_tags = local.common_tags
  
  depends_on = [module.eks]
}

#==========================================
# EKS Module
#==========================================
module "eks" {
  source = "../../modules/eks"
  
  # Basic Configuration
  environment  = local.environment
  project      = local.project
  cluster_name = var.cluster_name
  
  # Kubernetes Version
  cluster_version = var.cluster_version
  
  # Networking
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  
  # IAM Roles
  cluster_service_role_arn = module.iam.cluster_service_role_arn
  node_group_role_arn     = module.iam.node_group_role_arn
  
  # Node Group Configuration
  node_groups = var.node_groups
  
  # Cluster Addons
  cluster_addons = var.cluster_addons
  
  # Access Configuration
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  
  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types
  
  # Tags
  common_tags = local.common_tags
  
  depends_on = [module.vpc, module.security_groups, module.iam]
}

#==========================================
# EBS CSI Module
#==========================================
module "ebs_csi" {
  source = "../../modules/ebs-csi"
  
  cluster_name        = module.eks.cluster_name
  oidc_provider_arn   = module.eks.cluster_oidc_provider_arn
  oidc_provider_url   = module.eks.cluster_oidc_provider_url
  
  tags = local.common_tags
  
  depends_on = [module.eks]
}
