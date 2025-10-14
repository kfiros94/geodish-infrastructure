# modules/logging/main.tf

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
  }
}

#==========================================
# Create Logging Namespace
#==========================================
resource "kubernetes_namespace" "logging" {
  metadata {
    name = var.logging_namespace
    labels = {
      name = var.logging_namespace
    }
  }
}

#==========================================
# Deploy Elasticsearch
#==========================================
resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "7.17.3"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  timeout = 900  # 15 minutes

  values = [
    yamlencode({
      replicas = var.elasticsearch_replicas
      
      # Minimize resource usage for dev
      esJavaOpts = "-Xmx1g -Xms1g"
      
      resources = {
        limits = {
          cpu    = "1000m"
          memory = var.elasticsearch_memory_limit
        }
        requests = {
          cpu    = "500m"
          memory = var.elasticsearch_memory_request
        }
      }
      
      # Persistent storage
      volumeClaimTemplate = {
        accessModes = ["ReadWriteOnce"]
        storageClassName = "ebs-grafana-retain"
        resources = {
          requests = {
            storage = var.elasticsearch_storage_size
          }
        }
      }
      
      # Security - disable for simplicity in dev
      protocol = "http"
      
      # Single node config for dev
      clusterHealthCheckParams = "wait_for_status=yellow&timeout=1s"
    })
  ]

  depends_on = [kubernetes_namespace.logging]
}
#==========================================
# Deploy Fluentd (Log Collector)
#==========================================
resource "helm_release" "fluentd" {
  name       = "fluentd"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluentd"
  version    = "0.5.2"  # ← Updated version (removes PSP)
  namespace  = kubernetes_namespace.logging.metadata[0].name

  values = [
    yamlencode({
      # Deploy as DaemonSet (one pod per node)
      kind = "DaemonSet"
      
      resources = {
        limits = {
          cpu    = "200m"
          memory = var.fluentd_memory_limit
        }
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
      }
      
      # Disable PodSecurityPolicy (not supported in K8s 1.25+)
      podSecurityPolicy = {
        enabled = false
      }
      
      # Elasticsearch output configuration
      fileconfigs = {
        "04_outputs.conf" = <<-EOF
          <match **>
            @type elasticsearch
            @id out_es
            @log_level info
            include_tag_key true
            host elasticsearch-master.${var.logging_namespace}.svc.cluster.local
            port 9200
            path ""
            scheme http
            ssl_verify false
            logstash_format true
            logstash_prefix fluentd
            logstash_dateformat %Y.%m.%d
            include_timestamp false
            type_name _doc
            <buffer>
              @type file
              path /var/log/fluentd-buffers/kubernetes.system.buffer
              flush_mode interval
              retry_type exponential_backoff
              flush_thread_count 2
              flush_interval 5s
              retry_forever
              retry_max_interval 30
              chunk_limit_size 2M
              queue_limit_length 8
              overflow_action block
            </buffer>
          </match>
        EOF
      }
    })
  ]

  depends_on = [helm_release.elasticsearch]
}
#==========================================
# Deploy Kibana (Log Visualization UI)
#==========================================
resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "7.17.3"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  timeout = 600  # 10 minutes

  values = [
    yamlencode({
      replicas = var.kibana_replicas
      
      # Elasticsearch connection
      elasticsearchHosts = "http://elasticsearch-master.${var.logging_namespace}.svc.cluster.local:9200"
      
      # Service configuration - LoadBalancer for easy access
      service = {
        type = "LoadBalancer"
        port = 5601
      }
      
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
      
      # Health checks
      healthCheckPath = "/api/status"
      
      # Kibana configuration
      kibanaConfig = {
        "kibana.yml" = <<-EOF
          server.host: "0.0.0.0"
          elasticsearch.hosts: ["http://elasticsearch-master.${var.logging_namespace}.svc.cluster.local:9200"]
        EOF
      }
    })
  ]

  depends_on = [helm_release.elasticsearch]
}