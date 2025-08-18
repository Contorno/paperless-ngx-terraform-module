terraform {
  required_version = ">= 1.12.2"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Generate random passwords for security
resource "random_password" "paperless_secret_key" {
  length  = 50
  special = true
}

resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

module "paperless" {
  source = "../.."

  name = "paperless"
  labels = {
    app         = "paperless-ngx"
    environment = "dev"
    managed-by  = "terraform"
  }

  # Required secrets
  paperless_secret_key  = random_password.paperless_secret_key.result
  paperless_postgres_pw = random_password.postgres_password.result

  # Storage configuration
  postgres_storage_size           = "10Gi"
  redis_storage_size             = "5Gi"
  paperless_data_storage_size    = "10Gi"
  paperless_media_storage_size   = "50Gi"
  paperless_export_storage_size  = "10Gi"
  paperless_consume_storage_size = "10Gi"

  # Optional: Enable external access
  enable_ingress      = false  # Set to true if you want external access
  enable_tls          = false  # Set to true for HTTPS
  ingress_host        = "paperless.example.com"
  cert_manager_issuer = "letsencrypt-prod"

  # Optional: Enable Paperless AI
  enable_paperless_ai       = false  # Set to true to enable
  paperless_ai_storage_size = "5Gi"

  # Optional: Environment variables override
  environment_variables = {
    PAPERLESS_TIME_ZONE    = "America/New_York"
    PAPERLESS_OCR_LANGUAGE = "eng+spa"  # English + Spanish
  }
}

# Outputs
output "module_name" {
  description = "The name of the module"
  value       = module.paperless.module_name
}

output "namespace" {
  description = "The Kubernetes namespace where Paperless is deployed"
  value       = module.paperless.namespace
}

output "paperless_service_name" {
  description = "The name of the Paperless service"
  value       = module.paperless.paperless_service_name
}

output "paperless_url" {
  description = "URL to access Paperless (if ingress is enabled)"
  value       = module.paperless.paperless_url
}

output "postgres_service_name" {
  description = "The name of the PostgreSQL service"
  value       = module.paperless.postgres_service_name
}

output "redis_service_name" {
  description = "The name of the Redis service"
  value       = module.paperless.redis_service_name
}