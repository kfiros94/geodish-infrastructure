# modules/argocd/main.tf

terraform {
  required_providers {
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
}

#==========================================
# Create Namespaces
#==========================================

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}

#==========================================
# Install ArgoCD via Helm
#==========================================

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }
      
      server = {
        service = {
          type = "LoadBalancer"
        }
        extraArgs = [
          "--insecure"
        ]
      }
      
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

#==========================================
# Create MongoDB Secret
#==========================================

resource "kubernetes_secret" "mongodb_credentials" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    password         = base64encode(var.mongodb_password)
    connectionString = base64encode("mongodb://${var.mongodb_username}:${var.mongodb_password}@geodish-mongodb-svc.${var.app_namespace}.svc.cluster.local:27017/${var.mongodb_database}?authSource=admin")
  }

  type = "Opaque"
}

#==========================================
# Wait for ArgoCD to be Ready
#==========================================

resource "time_sleep" "wait_for_argocd" {
  create_duration = "90s"
  depends_on      = [helm_release.argocd]
}

#==========================================
# Deploy Root ArgoCD Application
#==========================================

resource "kubectl_manifest" "root_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    
    metadata = {
      name      = "geodish-root-app"
      namespace = var.argocd_namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.git_repo_url
        path           = "helm-charts/app-of-apps"
        targetRevision = var.git_target_revision
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [time_sleep.wait_for_argocd]
}