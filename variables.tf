variable "name" {
  description = "A name to identify resources created by this module."
  type        = string
  default     = "example"
}

variable "labels" {
  description = "Common labels/tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Additional environment variables for Paperless-ngx"
  type        = map(string)
  default     = {}
}

variable "service_type" {
  description = "Kubernetes service type for Paperless-ngx"
  type        = string
  default     = "ClusterIP"
}

variable "postgres_storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "10Gi"
}

variable "redis_storage_size" {
  description = "Storage size for Redis"
  type        = string
  default     = "5Gi"
}

variable "paperless_data_storage_size" {
  description = "Storage size for Paperless-ngx data"
  type        = string
  default     = "50Gi"
}

variable "paperless_media_storage_size" {
  description = "Storage size for Paperless-ngx media"
  type        = string
  default     = "50Gi"
}

variable "paperless_export_storage_size" {
  description = "Storage size for Paperless-ngx export"
  type        = string
  default     = "50Gi"
}

variable "paperless_consume_storage_size" {
  description = "Storage size for Paperless-ngx consume"
  type        = string
  default     = "10Gi"
}

variable "storage_class_name" {
  description = "StorageClass to use for PVCs. If null, uses cluster default"
  type        = string
  default     = null
}

variable "paperless_secret_key" {
    description = "The secret key used by paperless"
    type        = string
    sensitive = true
}

variable "paperless_postgres_pw" {
    description = "Password for the paperless Postgres database"
    type        = string
    sensitive = true
}

variable "enable_ingress" {
  description = "Enable external ingress for Paperless-ngx"
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "External hostname for the ingress"
  type        = string
  default     = "localhost"
}

variable "ingress_annotations" {
  description = "Additional annotations for the ingress"
  type        = map(string)
  default     = {}
}

variable "ingress_class" {
  description = "Ingress class to use"
  type        = string
  default     = "nginx"
}

variable "enable_tls" {
  description = "Enable TLS/HTTPS for the ingress"
  type        = bool
  default     = true
}

variable "cert_manager_issuer" {
  description = "Cert-manager cluster issuer for Let's Encrypt certificates"
  type        = string
  default     = "letsencrypt-prod"
}