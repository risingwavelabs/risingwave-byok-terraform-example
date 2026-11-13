module "heap_storage" {
  source = "../modules/heap_storage"

  bucket_name       = "${local.name_prefix}-heap-${data.aws_caller_identity.current.account_id}"
  role_name         = "${local.name_prefix}-s3-csi"
  oidc_provider_arn = module.eks.oidc_provider_arn
  retention_days    = var.heap_retention_days
  tags              = local.tags
}
