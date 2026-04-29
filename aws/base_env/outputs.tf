# ------------------------------------------------------------------------------
# Outputs - All values needed to configure k8s_resources_byok module
# ------------------------------------------------------------------------------

# General
output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "name_prefix" {
  description = "Name prefix used for all resources"
  value       = local.name_prefix
}

output "control_plane_aws_account_id" {
  description = "Control plane AWS account ID"
  value       = var.control_plane_aws_account_id
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks (for NLB TargetGroupBinding config)"
  value       = module.vpc.private_subnets_cidr_blocks
}

# EKS
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

# S3
output "s3_bucket_name" {
  description = "S3 bucket name for RisingWave data"
  value       = aws_s3_bucket.risingwave_data.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for RisingWave data"
  value       = aws_s3_bucket.risingwave_data.arn
}

# Terraform State
output "terraform_state_s3_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

# KMS
output "ebs_encryption_key_arn" {
  description = "KMS key ARN for EBS encryption"
  value       = module.ebs_kms_key.key_arn
}

# Loki (Hosted Telemetry)
output "loki_s3_bucket_name" {
  description = "S3 bucket name for Loki log storage"
  value       = aws_s3_bucket.loki_logs.id
}

output "loki_s3_bucket_arn" {
  description = "S3 bucket ARN for Loki log storage"
  value       = aws_s3_bucket.loki_logs.arn
}

output "loki_role_arn" {
  description = "IAM role ARN for Loki S3 access"
  value       = module.loki_irsa_role.arn
}

# IAM Roles
output "cloudagent_role_arn" {
  description = "IAM role ARN for CloudAgent"
  value       = module.cloudagent_irsa_role.arn
}

output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.aws_lb_controller_irsa_role.iam_role_arn
}

# NLBs and Target Groups
output "cloudagent_nlb_arn" {
  description = "CloudAgent NLB ARN"
  value       = aws_lb.cloudagent.arn
}

output "cloudagent_nlb_dns_name" {
  description = "CloudAgent NLB DNS name"
  value       = aws_lb.cloudagent.dns_name
}

output "cloudagent_target_group_arn" {
  description = "CloudAgent target group ARN (main port)"
  value       = aws_lb_target_group.cloudagent.arn
}

output "cloudagent_zpage_target_group_arn" {
  description = "CloudAgent zpage target group ARN"
  value       = aws_lb_target_group.cloudagent_zpage.arn
}

output "rwproxy_internal_nlb_arn" {
  description = "RWProxy internal NLB ARN"
  value       = aws_lb.rwproxy_internal.arn
}

output "rwproxy_internal_nlb_dns_name" {
  description = "RWProxy internal NLB DNS name"
  value       = aws_lb.rwproxy_internal.dns_name
}

output "rwproxy_internal_target_group_arn" {
  description = "RWProxy internal target group ARN"
  value       = aws_lb_target_group.rwproxy_internal.arn
}

output "rwproxy_webhook_target_group_arn" {
  description = "RWProxy webhook target group ARN"
  value       = aws_lb_target_group.rwproxy_webhook.arn
}

output "rwproxy_metrics_target_group_arn" {
  description = "RWProxy metrics target group ARN"
  value       = aws_lb_target_group.rwproxy_metrics.arn
}

# VPC Endpoint Services
output "cloudagent_vpc_endpoint_service_name" {
  description = "CloudAgent VPC Endpoint Service name"
  value       = aws_vpc_endpoint_service.cloudagent.service_name
}

output "rwproxy_vpc_endpoint_service_name" {
  description = "RWProxy VPC Endpoint Service name"
  value       = aws_vpc_endpoint_service.rwproxy.service_name
}

# Custom Tags
output "tags" {
  description = "User-provided custom tags"
  value       = var.tags
}

# ------------------------------------------------------------------------------
# Convenience output: k8s_resources_byok module input variables
# Copy this to your k8s_resources_byok tfvars or use as module input
# ------------------------------------------------------------------------------
output "k8s_resources_byok_inputs" {
  description = "Input values for k8s_resources_byok module"
  sensitive   = true
  value = {
    aws_account_id                    = data.aws_caller_identity.current.account_id
    region                            = var.region
    uuid                              = var.user_prefix
    env_name                          = "${local.name_prefix}-env"
    eks_cluster_name                  = module.eks.cluster_name
    s3_bucket_name                    = aws_s3_bucket.risingwave_data.id
    s3_bucket_arn                     = aws_s3_bucket.risingwave_data.arn
    ebs_encryption_key_arn            = module.ebs_kms_key.key_arn
    cloudagent_nlb_subnet_cidrs       = module.vpc.private_subnets_cidr_blocks
    rwproxy_nlb_subnet_cidrs          = module.vpc.private_subnets_cidr_blocks
    cloudagent_role_arn               = module.cloudagent_irsa_role.arn
    cloudagent_target_group_arn       = aws_lb_target_group.cloudagent.arn
    cloudagent_zpage_target_group_arn = aws_lb_target_group.cloudagent_zpage.arn
    rwproxy_internal_target_group_arn = aws_lb_target_group.rwproxy_internal.arn
    rwproxy_webhook_target_group_arn  = aws_lb_target_group.rwproxy_webhook.arn
    rwproxy_metrics_target_group_arn  = aws_lb_target_group.rwproxy_metrics.arn
    cluster_metrics_mode              = "hosted_vm"
    cluster_logging_mode              = "hosted_loki"
    loki_s3_bucket_arn                = aws_s3_bucket.loki_logs.arn
    loki_role_arn                     = module.loki_irsa_role.arn
  }
}
