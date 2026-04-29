# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "iam_role_arn" {
  description = "IAM role ARN for the tenant (pass to byok-config YAML as aws.iam_role_arn)."
  value       = aws_iam_role.tenant.arn
}

output "metastore_host" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.metastore.address
}

output "metastore_port" {
  description = "RDS endpoint port."
  value       = aws_db_instance.metastore.port
}

output "metastore_database" {
  description = "Database name."
  value       = aws_db_instance.metastore.db_name
}

output "metastore_username" {
  description = "Database username."
  value       = aws_db_instance.metastore.username
}

# ------------------------------------------------------------------------------
# Convenience: full byok-tenant-config YAML for `rwc cluster byok-config --config`
# Usage: terraform output -raw byok_tenant_config_yaml > /tmp/byok-tenant-config.yaml
# ------------------------------------------------------------------------------
output "byok_tenant_config_yaml" {
  description = "YAML config for `rwc cluster byok-config --config`. Password must be supplied via RWC_BYOK_METASTORE_PASSWORD env var."
  value       = <<-YAML
    aws:
      iam_role_arn: ${aws_iam_role.tenant.arn}
    metastore:
      host: ${aws_db_instance.metastore.address}
      port: ${aws_db_instance.metastore.port}
      database: ${aws_db_instance.metastore.db_name}
      username: ${aws_db_instance.metastore.username}
  YAML
}
