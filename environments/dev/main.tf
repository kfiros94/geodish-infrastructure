# environments/dev/main.tf

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

# ADDED: ArgoCD Installation via Helm
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
      # Disable notifications controller to reduce resource usage
      notifications = {
        enabled = false
      }
      # Disable dex for simplicity
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

# ADDED: GeoDish Root Application - Automatic GitOps Deployment
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
  
  depends_on = [
    helm_release.argocd
  ]
}

# ADDED: Wait for ArgoCD to be ready before deploying applications
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  
  create_duration = "60s"
}

# Update the dependency for the root app
resource "kubernetes_manifest" "geodish_root_app_final" {
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
  
  depends_on = [
    time_sleep.wait_for_argocd
  ]
}
