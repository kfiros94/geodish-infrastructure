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

# Local values for common tags
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "devops-team"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  
  availability_zones = data.aws_availability_zones.available.names
  
  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  project_name           = var.project_name
  environment           = var.environment
  cluster_version       = var.cluster_version
  
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  
  cluster_service_role_arn    = module.iam.cluster_service_role_arn
  node_group_instance_role_arn = module.iam.node_group_instance_role_arn
  
  node_group_instance_types = var.node_group_instance_types
  node_group_capacity_type  = var.node_group_capacity_type
  node_group_scaling_config = var.node_group_scaling_config
  
  tags = local.common_tags
  
  depends_on = [module.vpc, module.iam]
}

# EBS CSI Driver Module
module "ebs_csi" {
  source = "../../modules/ebs-csi"
  
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  
  tags = local.common_tags
  
  depends_on = [module.eks]
}

# ArgoCD Installation via Helm (FULFILLS MENTOR'S REQUIREMENT)
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "7.6.12"
  
  create_namespace = true
  
  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      notifications = {
        enabled = false
      }
      dex = {
        enabled = false
      }
    })
  ]
  
  depends_on = [
    module.eks,
    module.ebs_csi
  ]
}

# Wait for ArgoCD to be ready
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "90s"
}

# GeoDish Root Application (FULFILLS MENTOR'S REQUIREMENT)
resource "kubernetes_manifest" "geodish_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "geodish-root-app"
      namespace = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/kfiros94/geodish-gitops.git"
        path           = "helm-charts/app-of-apps"
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}
