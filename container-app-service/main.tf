terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli = false
}

locals {
  # Container Apps secret names must be lowercase alphanumeric/dashes, so
  # env var keys (e.g. "Google__ClientId") get a sanitized secret name.
  secret_env_names = { for k, v in var.secret_env_vars : k => lower(replace(k, "_", "-")) }
}

resource "azurerm_container_app" "this" {
  name                         = var.service_name
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  secret {
    name  = "ghcr-pat"
    value = var.ghcr_pat
  }

  dynamic "secret" {
    for_each = var.secret_env_vars
    content {
      name  = local.secret_env_names[secret.key]
      value = secret.value
    }
  }

  registry {
    server               = "ghcr.io"
    username             = var.ghcr_username
    password_secret_name = "ghcr-pat"
  }

  template {
    container {
      name   = var.service_name
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name        = env.key
          secret_name = local.secret_env_names[env.key]
        }
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.container_port
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}