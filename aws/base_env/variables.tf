variable "user_prefix" {
  type        = string
  description = <<-HELP
  A unique prefix to identify resources created by this user.
  This ensures multiple users can run the module simultaneously without conflicts.
  Example: "junfeng", "alice", "team1"
  HELP

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,11}$", var.user_prefix))
    error_message = "user_prefix must be 1-12 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "region" {
  type        = string
  description = "AWS region for the BYOK test environment."
  default     = "us-east-1"
}

variable "control_plane_aws_account_id" {
  type        = string
  description = "The AWS account ID where the RisingWave control plane is hosted (for VPC endpoint service allowed principals)."
  default     = "600598779918" # RisingWave Cloud production
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = <<-HELP
  AWS Availability Zone names for VPC subnets and NLBs. With AZ-aware VPC
  endpoint filtering on the control plane (CLOUD-4804), customers can use
  any AZs — the control plane dynamically selects matching subnets.
  Defaults to the first 3 AZs in the region.
  HELP
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) >= 2
    error_message = "availability_zones must be empty (auto-detect) or list at least 2 AZs."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for EKS cluster."
  default     = "1.33"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources."
}

# ------------------------------------------------------------------------------
# Ports (must match what k8s_resources_byok expects)
# ------------------------------------------------------------------------------
variable "cloudagent_port" {
  type        = number
  description = "Port for CloudAgent service."
  default     = 40001
}

variable "cloudagent_zpage_port" {
  type        = number
  description = "Port for CloudAgent zpage (debug) endpoint."
  default     = 40090
}

variable "rwproxy_port" {
  type        = number
  description = "Port for RWProxy service (Postgres protocol)."
  default     = 4566
}

variable "rwproxy_webhook_port" {
  type        = number
  description = "Port for RWProxy webhook service."
  default     = 4580
}

variable "rwproxy_webhook_listener_port" {
  type        = number
  description = "NLB listener port for RWProxy webhook (externally exposed port)."
  default     = 443
}

variable "rwproxy_metrics_port" {
  type        = number
  description = "Port for RWProxy metrics endpoint."
  default     = 9099
}
