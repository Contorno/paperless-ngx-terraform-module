# Paperless AI Deployment
resource "kubernetes_deployment" "paperless_ai" {
  metadata {
    name      = "${local.module_name}-ai"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-ai"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-ai"
        })
      }

      spec {
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
        }

        container {
          image = "clusterzx/paperless-ai:latest"
          name  = "paperless-ai"

          security_context {
            run_as_user                = 1000
            run_as_group               = 1000
            run_as_non_root            = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          port {
            container_port = 3001
          }

          # Environment variables from Docker Compose
          env {
            name  = "PUID"
            value = "1000"
          }
          env {
            name  = "PGID"
            value = "1000"
          }
          env {
            name  = "PAPERLESS_AI_PORT"
            value = "3001"
          }
          env {
            name  = "RAG_SERVICE_URL"
            value = var.paperless_url
          }
          env {
            name  = "RAG_SERVICE_ENABLED"
            value = "true"
          }

          # Resource limits
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "2Gi"
            }
          }

          # Volume mounts
          volume_mount {
            name       = "paperless-ai-data"
            mount_path = "/app/data"
          }
          volume_mount {
            name       = "paperless-ai-logs"
            mount_path = "/app/logs"
          }
          volume_mount {
            name       = "paperless-ai-openapi"
            mount_path = "/app/OPENAPI"
          }
          volume_mount {
            name       = "paperless-ai-public"
            mount_path = "/app/public/images"
          }
          volume_mount {
            name       = "paperless-ai-tmp"
            mount_path = "/tmp"
          }
        }

        # Volumes
        volume {
          name = "paperless-ai-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_ai_data.metadata[0].name
          }
        }
        volume {
          name = "paperless-ai-logs"
          empty_dir {
            medium = "Memory"
          }
        }
        volume {
          name = "paperless-ai-openapi"
          empty_dir {
            medium = "Memory"
          }
        }
        volume {
          name = "paperless-ai-public"
          empty_dir {
            size_limit = "1Gi"  # For thumbnail images
          }
        }
        volume {
          name = "paperless-ai-tmp"
          empty_dir {
            size_limit = "1Gi"
          }
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [
    kubernetes_deployment.paperless
  ]
}

# Paperless AI Service
resource "kubernetes_service" "paperless_ai" {

  metadata {
    name      = "${local.module_name}-ai-service"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
    annotations = merge(
      {},
      try(var.paperless_ai_service_annotations, {})
    )
  }
  spec {
    selector = {
      app = "${local.module_name}-ai"
    }

    port {
      port        = 3001
      target_port = 3001
      protocol    = "TCP"
    }

    type = var.paperless_ai_service_type
  }
}

# Paperless AI PVC for data persistence
resource "kubernetes_persistent_volume_claim" "paperless_ai_data" {

  metadata {
    name      = "${local.module_name}-ai-data"
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

resource "kubernetes_ingress_v1" "paperless_ai_tailscale" {
  metadata {
    name      = "${local.module_name}-ai-tailscale"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    ingress_class_name = "tailscale"

    default_backend {
      service {
        name = kubernetes_service.paperless_ai.metadata[0].name
        port {
          number = 3001
        }
      }
    }

    tls {
      hosts = ["paperless-ai"]
    }
  }
}
