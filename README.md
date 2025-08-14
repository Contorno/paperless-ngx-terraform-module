# paperless-ngx-terraform-module

A Terraform module to spin-up Paperless-ngx on Kubernetes.
## Usage

```hcl
module "paperless" {
  source = "github.com/your-org/paperless-ngx-terraform-module//?ref=v0.1.0"

  name   = "paperless"
  labels = {
    app = "paperless-ngx"
  }

  # Add provider-specific inputs here (e.g., kubernetes, helm, etc.)
}
```

For local development:

```hcl
module "paperless" {
  source = "../" # or "./" from the example folder
  name   = "paperless"
}
```

## Inputs

- name (string): A name to identify resources created by this module. Default: "example"
- labels (map(string)): Common labels/tags to apply to resources. Default: {}

## Outputs

- module_name (string): The name used to identify resources in this module.

## Requirements

- Terraform >= 1.12

## Development

- Format: `terraform fmt -recursive`
- Validate: `terraform init -backend=false && terraform validate`
- Test example: `cd examples/basic && terraform init -backend=false && terraform validate`

## Releasing

- Create a tag (e.g., `v0.1.0`) on the default branch to publish a version consumers can pin to.

## License

MIT
