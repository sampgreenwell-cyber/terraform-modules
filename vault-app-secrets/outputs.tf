output "role" {
  description = "Set as VAULT_ROLE on the service."
  value       = vault_azure_auth_backend_role.this.role
}
output "secrets_path" {
  value = "${var.kv_mount}/apps/${var.service_name}"
}
output "cert_path" {
  description = "Set as VAULT_CERT_PATH on the service: the path its CSR is posted to. null without pki_mount."
  value       = local.pki ? "${var.pki_mount}/sign/${local.name}" : null
}
