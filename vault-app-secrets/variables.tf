variable "service_name" {
  type        = string
  description = "Service (repo) name. Secrets live under kv/apps/<service_name>/, the role and policy are app-<service_name>."
}
variable "principal_id" {
  type        = string
  description = "Object (principal) ID of the service's user-assigned managed identity."
}
variable "kv_mount" {
  type    = string
  default = "kv"
}
variable "azure_auth_path" {
  type    = string
  default = "azure"
}
variable "token_ttl" {
  type    = number
  default = 3600
}
variable "pki_mount" {
  type        = string
  default     = null
  description = "PKI mount that signs this service's certificates (e.g. pki_int). null (the default) turns certificates off."
}
variable "pki_domain" {
  type        = string
  default     = "lab.internal"
  description = "The certificate name is <service_name>.<pki_domain>, and only that name."
}
variable "pki_cert_ttl" {
  type        = number
  default     = 3600
  description = "Certificate lifetime in seconds (role ttl and max_ttl). The app renews at about two thirds of it."
}
