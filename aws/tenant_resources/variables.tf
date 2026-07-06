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
  description = <<-HELP
  Master password for the RDS metastore. RisingWave Cloud embeds this in the
  metastore connection URL, so it must use only RFC 3986 unreserved characters:
  A-Z a-z 0-9 and _ ~ . -  (no @ / : or spaces). AWS RDS itself accepts a wider
  set, but `rwc cluster byok-config` rejects anything outside this alphabet with
  HTTP 400 — validate here so a bad password fails at plan time, before the RDS
  instance is ever created.
  HELP
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_~.-]{8,128}$", var.rds_password))
    error_message = "rds_password must be 8-128 characters from the RisingWave-supported alphabet: A-Z a-z 0-9 _ ~ . - (RDS accepts more, but rwc cluster byok-config rejects them)."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources."
}
