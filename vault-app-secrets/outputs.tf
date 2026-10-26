output "role" {
  description = "Set as VAULT_ROLE on the service."
  value       = vault_azure_auth_backend_role.this.role
}
output "secrets_path" {
  value = "${var.kv_mount}/apps/${var.service_name}"
}
