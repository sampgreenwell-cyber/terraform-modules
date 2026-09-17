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