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
  pki  = var.pki_mount != null
  # Terraform evaluates both branches of a conditional, so never interpolate a null mount.
  pki_mount = local.pki ? var.pki_mount : ""

  # Read-only access to this service's own secrets: kv/apps/<service>/*
  kv_policy = <<-EOT
    path "${var.kv_mount}/data/apps/${var.service_name}/*" {
      capabilities = ["read"]
    }
  EOT

  # With PKI: sign a CSR for its own name, nothing else (no issue, no other roles, no revoke).
  # The app keeps its private key; Vault only sees the CSR.
  pki_policy = local.pki ? (<<-EOT
    path "${local.pki_mount}/sign/${local.name}" {
      capabilities = ["update"]
    }
  EOT
  ) : ""
}

resource "vault_policy" "this" {
  name   = local.name
  policy = "${local.kv_policy}${local.pki_policy}"
}

# Certificates for exactly <service>.<pki_domain>, EC P-256, short-lived. Created only with pki_mount.
resource "vault_pki_secret_backend_role" "this" {
  count = local.pki ? 1 : 0

  backend            = var.pki_mount
  name               = local.name
  allowed_domains    = ["${var.service_name}.${var.pki_domain}"]
  allow_bare_domains = true
  allow_subdomains   = false
  allow_glob_domains = false
  allow_localhost    = false
  allow_ip_sans      = false
  enforce_hostnames  = true
  server_flag        = true
  client_flag        = true
  key_type           = "ec"
  key_bits           = 256
  # Seconds, as strings: Vault reads them back as numbers.
  ttl     = tostring(var.pki_cert_ttl)
  max_ttl = tostring(var.pki_cert_ttl)
  # Keep issued certificates listable (vault list <mount>/certs) until they expire.
  no_store = false
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
