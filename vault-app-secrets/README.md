# vault-app-secrets

Registers one golden-path service with Vault: a read-only policy for `kv/apps/<service>/*` and an
`azure/` auth role bound to the service's user-assigned managed identity. Applied from the Vault
config root (`sampgreenwell-cyber/vault`, `config/`), not from the service's own pipeline, so
services never need Vault admin rights.

```hcl
module "app_my_service" {
  source       = "git::https://github.com/sampgreenwell-cyber/terraform-modules.git//vault-app-secrets?ref=v1.2.0"
  service_name = "my-service"
  principal_id = "<principal ID of id-my-service>"
}
```

Then write the service's secrets as a human (`vault login -method=github`):

    vault kv put kv/apps/my-service/demo Demo__ApiKey=...

The app logs in with `VAULT_ROLE=app-my-service` and reads `kv/apps/my-service/demo` at startup.
