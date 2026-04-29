output "karpenter_node_iam_role_name" {
  description = "Node IAM role name from the Karpenter submodule."
  value       = one(module.karpenter_gear[*].node_iam_role_name)
}

output "karpenter_node_iam_role_arn" {
  description = "Node IAM role ARN from the Karpenter submodule."
  value       = one(module.karpenter_gear[*].node_iam_role_arn)
}
