variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace to associate with the Karpenter Pod Identity"
  type        = string
}

variable "irsa_service_account" {
  description = "Service account name used in trust policy for IAM role for service accounts"
  type        = string
}

variable "irsa_oidc_provider_arn" {
  description = "OIDC provider arn used in trust policy for IAM role for service accounts"
  type        = string
}

variable "additional_node_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the Karpenter-launched node role."
  type        = map(string)
  default     = {}
}
