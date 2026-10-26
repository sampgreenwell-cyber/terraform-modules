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
