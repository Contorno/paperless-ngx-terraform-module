# Paperless AI Deployment
resource "kubernetes_deployment" "paperless_ai" {
  count = var.enable_paperless_ai ? 1 : 0

  metadata {
    name      = "${local.module_name}-paperless-ai"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-paperless-ai"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-paperless-ai"
        })
      }

      spec {
        # Security context - simplified since the Docker command doesn't specify security opts
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
        }

        container {
          image = "clusterzx/paperless-ai:latest"
          name  = "paperless-ai"

          # Simplified environment variables to match Docker run
          env {
            name  = "PUID"
            value = "1000"
          }
          env {
            name  = "PGID"
            value = "1000"
          }

          port {
            container_port = 3000
          }

          # Resource limits
          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          # Simplified health checks - remove if the container doesn't have a health endpoint
          startup_probe {
            tcp_socket {
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 30
          }

          liveness_probe {
            tcp_socket {
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            tcp_socket {
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Volume mount for persistent data
          volume_mount {
            name       = "paperless-ai-data"
            mount_path = "/app/data"
          }
        }

        volume {
          name = "paperless-ai-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_ai_data[0].metadata[0].name
          }
        }

        # Restart policy (equivalent to restart: unless-stopped)
        restart_policy = "Always"
      }
    }
  }

  # Ensure paperless service is created first
  depends_on = [
    kubernetes_service.paperless
  ]
}

# Paperless AI Service
resource "kubernetes_service" "paperless_ai" {
  count = var.enable_paperless_ai ? 1 : 0

  metadata {
    name      = "${local.module_name}-paperless-ai"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-paperless-ai"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = var.paperless_ai_service_type
  }
}

# Paperless AI PVC for data persistence
resource "kubernetes_persistent_volume_claim" "paperless_ai_data" {
  count = var.enable_paperless_ai ? 1 : 0

  metadata {
    name      = "${local.module_name}-paperless-ai-data"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.paperless_ai_storage_size
      }
    }
  }
}

# Optional: Paperless AI Ingress
resource "kubernetes_ingress_v1" "paperless_ai_external" {
  count = var.enable_paperless_ai && var.enable_paperless_ai_ingress ? 1 : 0

  metadata {
    name      = "${local.module_name}-paperless-ai-external"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
    annotations = merge({
      "ingressClassName"                               = var.ingress_class
      "cert-manager.io/cluster-issuer"                 = var.cert_manager_issuer
      "nginx.ingress.kubernetes.io/ssl-redirect"       = var.enable_tls ? "true" : "false"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = var.enable_tls ? "true" : "false"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "100m"
    }, var.paperless_ai_ingress_annotations)
  }

  spec {
    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [var.paperless_ai_ingress_host]
        secret_name = "${local.module_name}-paperless-ai-tls-secret"
      }
    }

    rule {
      host = var.paperless_ai_ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.paperless_ai[0].metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}
