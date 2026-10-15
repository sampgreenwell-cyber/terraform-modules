# Personal lab stand-in for the gmnupr dev1 environment (Backstage golden path #2).
# Everything lives in one resource group, so teardown is `terraform destroy`.

locals {
  name           = "gmnupr-lab"
  tags           = { purpose = "backstage-golden-path-2-lab", owner = var.github_owner, ephemeral = "true" }
  subject_prefix = var.github_oidc_subject_prefix != "" ? var.github_oidc_subject_prefix : "repo:${var.github_owner}/${var.vwstate_lab_repo}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "random_string" "acr" {
  length  = 6
  upper   = false
  special = false
}

# Registry for the lab's service images (stands in for the work registry).
resource "azurerm_container_registry" "lab" {
  name                = "acrgmnuprlab${random_string.acr.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-${local.name}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  dns_prefix          = local.name
  sku_tier            = "Free"
  tags                = local.tags

  default_node_pool {
    name       = "system"
    vm_size    = var.node_vm_size
    node_count = var.node_count
    # The default 128 GB Premium OS disk costs about 4x this; the lab needs little space.
    os_disk_size_gb = 32

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
  }
}

# Nodes pull service images from the lab registry.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = azurerm_container_registry.lab.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.lab.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Identity the lab dev1 deploy workflow signs in as (GitHub OIDC, no secrets).
resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-${local.name}-deploy"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "deploy_lab_dev1" {
  name      = "vwstate-lab-env-lab-dev1"
  parent_id = azurerm_user_assigned_identity.deploy.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "${local.subject_prefix}:environment:lab-dev1"
}

# Cluster-scoped only: fetch admin credentials for this one cluster.
resource "azurerm_role_assignment" "deploy_cluster_admin" {
  scope                            = azurerm_kubernetes_cluster.lab.id
  role_definition_name             = "Azure Kubernetes Service Cluster Admin Role"
  principal_id                     = azurerm_user_assigned_identity.deploy.principal_id
  skip_service_principal_aad_check = true
}

# The deploy checks that every image it applies exists in the lab registry.
resource "azurerm_role_assignment" "deploy_acr_pull" {
  scope                            = azurerm_container_registry.lab.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.deploy.principal_id
  skip_service_principal_aad_check = true
}

# Identity that generated service repos sign in as to push images (GitHub OIDC).
# Initialize-LabRepo.ps1 adds one federated credential per service repo.
resource "azurerm_user_assigned_identity" "build" {
  name                = "id-${local.name}-build"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "build_acr_push" {
  scope                            = azurerm_container_registry.lab.id
  role_definition_name             = "AcrPush"
  principal_id                     = azurerm_user_assigned_identity.build.principal_id
  skip_service_principal_aad_check = true
}

# Budget alert: email at 100% of actual spend, and when forecast spend reaches 80%.
resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-${local.name}"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.monthly_budget_usd
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp())
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 80
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }

  lifecycle {
    # The start date is fixed when the budget is created.
    ignore_changes = [time_period]
  }
}
