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
  
  # Required parameters that your VPC module expects
  project_name = local.project
  environment  = local.environment
  
  # VPC Configuration (using your declared variables)
  vpc_cidr               = var.vpc_cidr
  availability_zones     = ["ap-south-1a", "ap-south-1b"]  # Hardcoded default
  public_subnet_cidrs    = var.public_subnet_cidrs  
  private_subnet_cidrs   = var.private_subnet_cidrs
  
  # NAT Gateway Configuration (hardcoded defaults since you don't have variables)
  enable_nat_gateway   = true   # Default for EKS
  single_nat_gateway   = true   # Cost optimization for dev
  
  # DNS Configuration (hardcoded defaults)
  enable_dns_hostnames = true   # Required for EKS
  enable_dns_support   = true   # Required for EKS
  
  # Tags
  tags = local.common_tags
}

#==========================================
# Security Groups Module
#==========================================
module "security_groups" {
  source = "../../modules/security-groups"
  
  # Required parameters
  project_name = local.project         
  environment  = local.environment
  cluster_name = "${local.project}-${local.environment}-eks"
  
  # VPC Configuration
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
  
  # Optional parameters 
  cluster_version = var.cluster_version
  
  # Tags
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
  
  # Feature flags (using your declared variables)
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
  
  # Basic Configuration
  project_name = local.project
  environment  = local.environment
  
  # Network Configuration
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  # Security Groups - FIXED NAMES
  cluster_security_group_ids = [module.security_groups.cluster_security_group_id]
  node_security_group_ids    = [module.security_groups.node_group_security_group_id]
  
  # IAM Configuration
  cluster_service_role_arn = module.iam.cluster_service_role_arn
  node_group_role_arn     = module.iam.node_group_role_arn
  
  # Node Group Configuration (using your declared variables)
  node_group_instance_types    = var.node_group_instance_types
  node_group_desired_capacity  = var.node_group_desired_capacity
  node_group_max_capacity      = var.node_group_max_capacity
  node_group_min_capacity      = var.node_group_min_capacity
  node_group_disk_size         = var.node_group_disk_size
  node_group_capacity_type     = "ON_DEMAND"
  
  # Cluster Configuration
  cluster_version = var.cluster_version
  
  # Enable features (using your declared variables)
  enable_irsa              = var.enable_irsa
  enable_ebs_csi_driver    = var.enable_ebs_csi_driver
  enable_cluster_autoscaler = false
  
  # Tags
  tags = local.common_tags
  
  depends_on = [module.vpc, module.security_groups, module.iam]
}

#==========================================
# EBS CSI Module
#==========================================
module "ebs_csi" {
  source = "../../modules/ebs-csi"
  
  # Required parameters - FIXED NAMES
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  
  # Optional parameters
  addon_version = null  # Use default version
  tags         = local.common_tags
  
  depends_on = [module.eks]
}