terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.0"
    }
  }
}

locals {
  name = "app-${var.service_name}"
}

# Read-only access to this service's own secrets: kv/apps/<service>/*
resource "vault_policy" "this" {
  name   = local.name
  policy = <<-EOT
    path "${var.kv_mount}/data/apps/${var.service_name}/*" {
      capabilities = ["read"]
    }
  EOT
}

# Login for the service's managed identity: only this principal gets this role.
resource "vault_azure_auth_backend_role" "this" {
  backend                     = var.azure_auth_path
  role                        = local.name
  bound_service_principal_ids = [var.principal_id]
  token_policies              = [vault_policy.this.name]
  token_ttl                   = var.token_ttl
  token_max_ttl               = var.token_ttl * 2
}
