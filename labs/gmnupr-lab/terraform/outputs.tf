output "resource_group" {
  value = azurerm_resource_group.lab.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.lab.name
}

output "acr_name" {
  value = azurerm_container_registry.lab.name
}

output "acr_login_server" {
  value = azurerm_container_registry.lab.login_server
}

output "deploy_client_id" {
  description = "AZURE_CLIENT_ID for the vwstate-lab lab-dev1 environment."
  value       = azurerm_user_assigned_identity.deploy.client_id
}

output "build_identity_name" {
  value = azurerm_user_assigned_identity.build.name
}

output "build_client_id" {
  description = "AZURE_CLIENT_ID for generated service repos' build workflow."
  value       = azurerm_user_assigned_identity.build.client_id
}

output "federated_subject" {
  value = azurerm_federated_identity_credential.deploy_lab_dev1.subject
}
