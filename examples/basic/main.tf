terraform {
  required_version = ">= 1.12.2"
}

module "paperless" {
  source = "../.."

  name = "paperless"
  labels = {
    app = "paperless-ngx"
  }
}

output "module_name" {
  value = module.paperless.module_name
}