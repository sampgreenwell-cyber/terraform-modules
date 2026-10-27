# vault-app-secrets

Registers one golden-path service with Vault: a read-only policy for `kv/apps/<service>/*` and an
`azure/` auth role bound to the service's user-assigned managed identity. Applied from the Vault
config root (`sampgreenwell-cyber/vault`, `config/`), not from the service's own pipeline, so
services never need Vault admin rights.

```hcl
module "app_my_service" {
  source       = "git::https://github.com/sampgreenwell-cyber/terraform-modules.git//vault-app-secrets?ref=v1.3.0"
  service_name = "my-service"
  principal_id = "<principal ID of id-my-service>"
}
```

Then write the service's secrets as a human (`vault login -method=github`):

    vault kv put kv/apps/my-service/demo Demo__ApiKey=...

The app logs in with `VAULT_ROLE=app-my-service` and reads `kv/apps/my-service/demo` at startup.

## Certificates (optional, v1.3.0+)

Set `pki_mount` to let the service get its own short-lived certificate from Vault's PKI engine:

```hcl
module "app_my_service" {
  source       = "git::https://github.com/sampgreenwell-cyber/terraform-modules.git//vault-app-secrets?ref=v1.3.0"
  service_name = "my-service"
  principal_id = "<principal ID of id-my-service>"
  pki_mount    = "pki_int"
}
```

This adds:

- PKI role `app-my-service` on `pki_int`: exactly `my-service.lab.internal` (no subdomains, globs,
  IPs or localhost), EC P-256 keys, lifetime `pki_cert_ttl` (default 3600 s).
- One policy line: `update` on `pki_int/sign/app-my-service`. That's `sign` only: the app creates
  its key and sends a CSR, so the private key never leaves it. No `issue`, other roles or revoke.
- Output `cert_path` (`pki_int/sign/app-my-service`), the app's `VAULT_CERT_PATH`.

Without `pki_mount` (the default) the module creates exactly what v1.2.0 did.
