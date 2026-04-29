variable "enabled" {
  description = "Whether to enable AWS Karpenter."
  type        = bool
  default     = true
}

variable "cluster_id" {
  description = "The name/id of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster."
  type        = string
}

variable "karpenter_namespace" {
  description = "The namespace running Karpenter under."
  type        = string
}

variable "irsa_service_account" {
  description = "Service account name used in trust policy for IAM role for service accounts"
  type        = string
}

variable "karpenter_controller_chart_version" {
  description = "Version of the helm chart used to create karpenter controller deployment."
  type        = string
}

variable "irsa_oidc_provider_arn" {
  description = "OIDC provider arn used in trust policy for IAM role for service accounts"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to the this set of managed resources."
  type        = map(string)
}

variable "additional_node_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the Karpenter-launched node role."
  type        = map(string)
  default     = {}
}

variable "use_private_helm_registry" {
  description = "Whether to use private Helm registry for Karpenter chart."
  type        = bool
  default     = false
}

variable "use_private_container_registry" {
  description = "Whether to use private container registry for Karpenter images."
  type        = bool
  default     = false
}

variable "private_helm_registry" {
  description = "Private Helm registry URL (OCI format)."
  type        = string
  default     = ""
}

variable "private_container_registry" {
  description = "Private container registry URL."
  type        = string
  default     = ""
}
