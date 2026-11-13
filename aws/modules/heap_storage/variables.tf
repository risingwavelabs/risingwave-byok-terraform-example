variable "bucket_name" {
  type        = string
  description = "Dedicated bucket for RisingWave heap dumps."
}

variable "role_name" {
  type        = string
  description = "IAM role for the Mountpoint S3 CSI driver service account."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider used to trust the driver service account."
}

variable "retention_days" {
  type        = number
  description = "Days before heap dumps expire."
  default     = 7
  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a positive whole number."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
