terraform {
  required_version = ">= 1.9" # cross-variable validation (work_github_orgs)

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State stays local (gitignored). The lab lives a few days and is destroyed.
}

provider "azurerm" {
  features {
    resource_group {
      # Teardown must remove everything, including anything created inside the group.
      prevent_deletion_if_contains_resources = false
    }
  }

  # Pinned so this can never run against another tenant or subscription.
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
