# terraform-modules

Shared, reusable Terraform modules for platform services.

## Modules

- `container-app-service` — provisions an Azure Container App pulling from GHCR.

## Prerequisite (one-time, per subscription)

The deploying service principal must have `Storage Blob Data Contributor`
on the Terraform state storage account before first use:

    az role assignment create --assignee <client-id> --role "Storage Blob Data Contributor" --scope <storage-account-resource-id>