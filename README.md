# terraform-modules

Shared, reusable Terraform modules for platform services.

## Modules

- `container-app-service` — provisions an Azure Container App pulling from GHCR.
- `vault-app-secrets` — registers a service with Vault: read-only policy for `kv/apps/<service>/*` and an `azure/` auth role for its managed identity.

## Prerequisite (one-time, per subscription)

The deploying service principal must have `Storage Blob Data Contributor`
on the Terraform state storage account before first use:

    az role assignment create --assignee <client-id> --role "Storage Blob Data Contributor" --scope <storage-account-resource-id>