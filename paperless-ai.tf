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
        container {
          image = "clusterzx/paperless-ai:latest"
          name  = "paperless-ai"

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
    kubernetes_deployment.paperless
  ]
}

# Paperless AI Service
resource "kubernetes_service" "paperless_ai" {
  count = var.enable_paperless_ai ? 1 : 0

  metadata {
    name      = "${local.module_name}-ai"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
    annotations = merge(
      {
        "app.kubernetes.io/name" = "${local.module_name}-ai"
      },
      try(var.paperless_ai_service_annotations, {})
    )
  }
  spec {
    selector = {
      app = "${local.module_name}-ai"
    }

    port {
      port        = 3001
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
