# ------------------------------------------------------------------------------
# Tenant identity (from `rwc cluster describe`)
# ------------------------------------------------------------------------------
variable "tenant_name" {
  type        = string
  description = <<-HELP
  Short, human-readable name for the tenant (e.g. \"dev\", \"prod\"). Used as a
  suffix in tenant-scoped resource names so multiple tenants in the same
  BYOK env don't collide (RDS instance, IAM role, etc.). Must be 1-32
  lowercase alphanumeric (hyphens allowed, not leading/trailing).
  HELP

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", var.tenant_name))
    error_message = "tenant_name must be 1-32 lowercase alphanumeric chars (hyphens allowed, not leading or trailing)."
  }
}

variable "tenant_namespace" {
  type        = string
  description = "Kubernetes namespace for the tenant (ResourceNamespace from rwc cluster describe)."
}

variable "tenant_service_account" {
  type        = string
  description = "Kubernetes service account name for the tenant (ServiceAccountName from rwc cluster describe)."
}

# ------------------------------------------------------------------------------
# RDS Configuration
# ------------------------------------------------------------------------------
variable "rds_instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.large"
}

variable "rds_db_name" {
  type        = string
  description = "Database name for the metastore."
  default     = "risingwave"
}

variable "rds_username" {
  type        = string
  description = "Master username for the RDS instance."
  default     = "risingwave"
}

variable "rds_password" {
  type        = string
  description = "Master password for the RDS instance."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources."
}
