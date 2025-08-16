########################################
# Module resources go here
########################################

locals {
  module_name = var.name
  labels      = var.labels
  secret_key  = var.paperless_secret_key
  pg_pw       = var.paperless_postgres_pw

  # Calculate the external URL based on ingress settings
  paperless_url = var.enable_ingress ? (var.enable_tls ? "https://${var.ingress_host}" : "http://${var.ingress_host}") : "http://localhost:8000"

  # Default environment variables from docker-compose.env
  paperless_env = merge({
    PAPERLESS_REDIS                   = "redis://${local.module_name}-redis:6379"
    PAPERLESS_DBENGINE                = "postgresql"
    PAPERLESS_DBHOST                  = "${local.module_name}-postgres"
    PAPERLESS_DBNAME                  = "paperless"
    PAPERLESS_DBUSER                  = "paperless"
    PAPERLESS_DBPASS                  = local.pg_pw
    PAPERLESS_DBPORT                  = "5432"
    PAPERLESS_TIKA_ENABLED            = "true"
    PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://${local.module_name}-gotenberg:3000"
    PAPERLESS_TIKA_ENDPOINT           = "http://${local.module_name}-tika:9998"
    PAPERLESS_SECRET_KEY              = local.secret_key
    PAPERLESS_URL                     = local.paperless_url
    PAPERLESS_TIME_ZONE               = "UTC"
    PAPERLESS_OCR_LANGUAGE            = "eng"
    PAPERLESS_OCR_LANGUAGES           = "por"
    PAPERLESS_ALLOWED_HOSTS           = var.enable_ingress ? "${var.ingress_host},localhost,127.0.0.1" : "localhost,127.0.0.1"
    PAPERLESS_CORS_ALLOWED_HOSTS      = var.enable_ingress ? "https://${var.ingress_host}" : "http://localhost:8000"
    PAPERLESS_USE_X_FORWARD_HOST      = var.enable_ingress ? "true" : "false"
    PAPERLESS_USE_X_FORWARD_PORT      = var.enable_ingress ? "true" : "false"
    PAPERLESS_USE_X_FORWARD_PROTO     = var.enable_ingress ? "true" : "false"
  }, var.environment_variables)
}

# Namespace
resource "kubernetes_namespace" "this" {
  metadata {
    name   = local.module_name
    labels = local.labels
  }
}

# PostgreSQL Deployment
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "${local.module_name}-postgres"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-postgres"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-postgres"
        })
      }

      spec {
        container {
          image = "postgres:17"
          name  = "postgres"

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }

          env {
            name  = "POSTGRES_DB"
            value = "paperless"
          }
          env {
            name  = "POSTGRES_USER"
            value = "paperless"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = local.pg_pw
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata[0].name
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "${local.module_name}-postgres"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

# PostgreSQL PVC
resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "${local.module_name}-postgres-data"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }
}

# Redis Deployment
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "${local.module_name}-redis"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-redis"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-redis"
        })
      }

      spec {
        container {
          image = "redis:8"
          name  = "redis"

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          port {
            container_port = 6379
          }

          volume_mount {
            name       = "redis-data"
            mount_path = "/data"
          }
        }

        volume {
          name = "redis-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis.metadata[0].name
          }
        }
      }
    }
  }
}

# Redis Service
resource "kubernetes_service" "redis" {
  metadata {
    name      = "${local.module_name}-redis"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }
  }
}

# Redis PVC
resource "kubernetes_persistent_volume_claim" "redis" {
  metadata {
    name      = "${local.module_name}-redis-data"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.redis_storage_size
      }
    }
  }
}

# Tika Deployment
resource "kubernetes_deployment" "tika" {
  metadata {
    name      = "${local.module_name}-tika"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-tika"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-tika"
        })
      }

      spec {
        container {
          image = "ghcr.io/paperless-ngx/tika:latest"
          name  = "tika"

          port {
            container_port = 9998
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }
      }
    }
  }
}

# Tika Service
resource "kubernetes_service" "tika" {
  metadata {
    name      = "${local.module_name}-tika"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-tika"
    }

    port {
      port        = 9998
      target_port = 9998
    }
  }
}

# Gotenberg Deployment
resource "kubernetes_deployment" "gotenberg" {
  metadata {
    name      = "${local.module_name}-gotenberg"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-gotenberg"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-gotenberg"
        })
      }

      spec {
        container {
          image = "gotenberg/gotenberg:7"
          name  = "gotenberg"

          command = [
            "gotenberg",
            "--chromium-disable-web-security=true",
            "--chromium-allow-list=file:///*"
          ]
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

          port {
            container_port = 3000
          }
        }
      }
    }
  }
}

# Gotenberg Service
resource "kubernetes_service" "gotenberg" {
  metadata {
    name      = "${local.module_name}-gotenberg"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-gotenberg"
    }

    port {
      port        = 3000
      target_port = 3000
    }
  }
}

# Paperless-ngx Deployment
resource "kubernetes_deployment" "paperless" {
  metadata {
    name      = "${local.module_name}-paperless"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${local.module_name}-paperless"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          app = "${local.module_name}-paperless"
        })
      }

      spec {
        container {
          image = "ghcr.io/paperless-ngx/paperless-ngx:latest"
          name  = "paperless"

          dynamic "env" {
            for_each = local.paperless_env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = 8000
          }

          volume_mount {
            name       = "paperless-data"
            mount_path = "/usr/src/paperless/data"
          }
          volume_mount {
            name       = "paperless-media"
            mount_path = "/usr/src/paperless/media"
          }
          volume_mount {
            name       = "paperless-export"
            mount_path = "/usr/src/paperless/export"
          }
          volume_mount {
            name       = "paperless-consume"
            mount_path = "/usr/src/paperless/consume"
          }
        }

        volume {
          name = "paperless-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_data.metadata[0].name
          }
        }
        volume {
          name = "paperless-media"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_media.metadata[0].name
          }
        }
        volume {
          name = "paperless-export"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_export.metadata[0].name
          }
        }
        volume {
          name = "paperless-consume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.paperless_consume.metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_service.postgres,
    kubernetes_service.redis,
    kubernetes_service.tika,
    kubernetes_service.gotenberg
  ]
}

# Paperless-ngx Service
resource "kubernetes_service" "paperless" {
  metadata {
    name      = "${local.module_name}-paperless"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      app = "${local.module_name}-paperless"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = var.service_type
  }
}

# Paperless-ngx PVCs
resource "kubernetes_persistent_volume_claim" "paperless_data" {
  metadata {
    name      = "${local.module_name}-paperless-data"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.paperless_data_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "paperless_media" {
  metadata {
    name      = "${local.module_name}-paperless-media"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.paperless_media_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "paperless_export" {
  metadata {
    name      = "${local.module_name}-paperless-export"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.paperless_export_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "paperless_consume" {
  metadata {
    name      = "${local.module_name}-paperless-consume"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.paperless_consume_storage_size
      }
    }
  }
}

# Paperless-ngx External Ingress with Let's Encrypt
resource "kubernetes_ingress_v1" "paperless_external" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "${local.module_name}-paperless-external"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
    annotations = merge({
      "ingressClassName"                                 = var.ingress_class
      "cert-manager.io/cluster-issuer"                   = var.cert_manager_issuer
      "nginx.ingress.kubernetes.io/ssl-redirect"         = var.enable_tls ? "true" : "false"
      "nginx.ingress.kubernetes.io/force-ssl-redirect"   = var.enable_tls ? "true" : "false"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "100m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"   = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"   = "600"
      "nginx.ingress.kubernetes.io/client-max-body-size" = "100m"
    }, var.ingress_annotations)
  }

  spec {
    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [var.ingress_host]
        secret_name = "${local.module_name}-tls-secret"
      }
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.paperless.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
