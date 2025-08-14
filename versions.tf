terraform {
  required_version = ">= 1.12.2"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    infisical = {
      version = "~> 0.15.28"
      source  = "infisical/infisical"
    }
  }
}
