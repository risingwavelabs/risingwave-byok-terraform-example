# ------------------------------------------------------------------------------
# Tenant identity (from `rwc cluster describe`)
# ------------------------------------------------------------------------------
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
