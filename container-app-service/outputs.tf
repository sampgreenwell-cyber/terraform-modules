output "url" {
  value = azurerm_container_app.this.latest_revision_fqdn
}
output "name" {
  value = azurerm_container_app.this.name
}
