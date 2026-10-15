# Values come from ../terraform.tfvars (gitignored); see ../terraform.tfvars.example.

variable "tenant_id" {
  description = "Personal lab tenant. Pinned in the provider."
  type        = string
}

variable "subscription_id" {
  description = "Personal lab subscription. Pinned in the provider."
  type        = string
}

variable "github_owner" {
  description = "GitHub account that owns the lab repositories."
  type        = string

  validation {
    condition     = !contains([for o in var.work_github_orgs : lower(o)], lower(var.github_owner))
    error_message = "The lab must never target a work GitHub org (work_github_orgs)."
  }
}

variable "work_github_orgs" {
  description = "Work GitHub orgs the lab must never target. Kept in terraform.tfvars so this public repo names no employer."
  type        = list(string)

  validation {
    condition     = length(var.work_github_orgs) > 0
    error_message = "List at least one work GitHub org, so the guard has something to refuse."
  }
}

variable "work_kube_context_pattern" {
  description = "Regex for work Kubernetes context names the lab must never use. Not used by Terraform; read by Test-LabTarget.ps1."
  type        = string
}

variable "alert_email" {
  description = "Where budget alerts are sent."
  type        = string
}

variable "owner_ip" {
  description = "Public IP allowed to reach the edge LoadBalancer. Not used by Terraform; read by the deploy workflow."
  type        = string
  default     = ""
}

variable "kube_context" {
  description = "Context name written to the lab kubeconfig. Not used by Terraform; read by the scripts."
  type        = string
  default     = "gmnupr-lab"
}

variable "location" {
  description = "Azure region (same as the personal Backstage)."
  type        = string
  default     = "eastus"
}

variable "vwstate_lab_repo" {
  description = "Lab vwstate repository name."
  type        = string
  default     = "vwstate-lab"
}

variable "github_oidc_subject_prefix" {
  description = "OIDC subject prefix GitHub sends for the lab vwstate repo: repo:<owner>/<repo>, or the immutable form repo:<owner>@<id>/<repo>@<id>. Read it with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub. Empty means repo:<owner>/<repo>."
  type        = string
  default     = ""
}

variable "node_vm_size" {
  description = "AKS node size. One D2as_v4 (2 vCPU, 8 GB) fits Envoy (about 0.5 vCPU requested) plus a few sample services. B2ms is not offered to the lab subscription in eastus."
  type        = string
  default     = "Standard_D2as_v4"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "monthly_budget_usd" {
  type    = number
  default = 100
}
