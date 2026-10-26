variable "service_name" {
  type = string
}
variable "image" {
  type = string
}
variable "container_port" {
  type    = number
  default = 8080
}
variable "resource_group_name" {
  type    = string
  default = "rg-platform-services"
}
variable "container_apps_environment_id" {
  type = string
}
variable "ghcr_pat" {
  type      = string
  sensitive = true
}
variable "ghcr_username" {
  type = string
}
variable "env_vars" {
  type        = map(string)
  default     = {}
  description = "Plaintext environment variables to set on the container, e.g. { Google__ClientId = \"...\" }."
}
variable "secret_env_vars" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Environment variables whose values are stored as Container Apps secrets, e.g. { YouTube__ApiKey = \"...\" }."
}
variable "user_assigned_identity_id" {
  type        = string
  default     = null
  description = "Resource ID of a user-assigned managed identity to attach, e.g. for Vault's azure auth method. null attaches none."
}
variable "min_replicas" {
  type        = number
  default     = null
  description = "Minimum replicas. null keeps the provider default (0, scale to zero)."
}
variable "max_replicas" {
  type        = number
  default     = null
  description = "Maximum replicas. null keeps the provider default (10)."
}
