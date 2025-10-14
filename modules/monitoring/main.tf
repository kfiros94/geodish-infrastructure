# modules/monitoring/main.tf

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
  }
}

#==========================================
# Create Monitoring Namespace
#==========================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      name = var.monitoring_namespace
    }
  }
}

#==========================================
# Deploy Prometheus + Grafana Stack
#==========================================
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention = "${var.retention_days}d"
          
          resources = {
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
          }
          
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "ebs-gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          
          # Enable service monitors
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }

      # Grafana configuration
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        
        service = {
          type = "LoadBalancer"
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

        persistence = {
        enabled          = true
        storageClassName = "ebs-grafana-retain"
        size             = var.grafana_storage_size
        # Add this:
        annotations = {
            "helm.sh/resource-policy" = "keep"
        }
        }

        # Pre-configured dashboard providers
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        # Import popular Kubernetes dashboards
        dashboards = {
          default = {
            # Kubernetes Cluster Monitoring
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            # Kubernetes Pods Monitoring
            kubernetes-pods = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }
            # Node Exporter Full
            node-exporter = {
              gnetId     = 1860
              revision   = 31
              datasource = "Prometheus"
            }
          }
        }
      }

      # AlertManager - disabled for dev
      alertmanager = {
        enabled = var.enable_alertmanager
      }

      # Enable essential components
      nodeExporter = {
        enabled = true
      }
      
      kubeStateMetrics = {
        enabled = true
      }
      
      prometheusOperator = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
#==========================================
# ServiceMonitor for GeoDish Application
#==========================================
resource "kubectl_manifest" "geodish_service_monitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "geodish-app"
      namespace = var.monitoring_namespace
      labels = {
        app     = "geodish-app"
        release = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "geodish-app"
        }
      }
      namespaceSelector = {
        matchNames = [var.app_namespace]
      }
      endpoints = [
        {
          port     = "http"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  })

  depends_on = [helm_release.prometheus]
}