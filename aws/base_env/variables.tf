variable "user_prefix" {
  type        = string
  description = <<-HELP
  A unique prefix to identify resources created by this user.
  This ensures multiple users can run the module simultaneously without conflicts.
  Example: "alice", "bob", "team1"
  HELP

  # Length capped at 20 because "byok-<user_prefix>-ca-zp" must fit in
  # the AWS NLB target group 32-char limit.
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,18}[a-z0-9])?$", var.user_prefix))
    error_message = "user_prefix must be 1-20 lowercase alphanumeric chars (hyphens allowed, not leading or trailing)."
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
    condition     = length(var.availability_zones) == 0 || (length(var.availability_zones) >= 2 && length(var.availability_zones) <= 3)
    error_message = "availability_zones must be empty (auto-detect) or list 2 or 3 AZs (subnet layout in vpc.tf supports up to 3)."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for EKS cluster."
  default     = "1.34"
}

variable "eks_auto_mode" {
  type        = bool
  description = <<-HELP
  Provision the EKS cluster in Auto Mode (custom node pools) instead of the
  standard OSS-Karpenter setup. When true:
    - the cluster enables compute_config + create_auto_mode_iam_resources
      (Auto Mode manages the node IAM role, and coredns/kube-proxy/vpc-cni/
      ebs-csi are built in), so those cluster addons, the Karpenter bootstrap
      managed node group, Security-Groups-for-Pods (ENABLE_POD_ENI), and the
      ebs-csi/vpc-cni IRSA roles are all dropped;
    - k8s_addons applies Auto Mode NodePools + eks.amazonaws.com/v1 NodeClasses
      instead of OSS Karpenter + EC2NodeClass.
  Create-time only: it cannot be flipped on an existing cluster (the two EBS
  CSI drivers cannot attach each other's volumes).
  HELP
  default     = false
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
