# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------

# BYOKConfig — complete YAML for use with the BYOK CLI.
# Built in byok_config.tf from base_env (via terraform_remote_state) + k8s_addons scheduling data.
output "byok_config_yaml" {
  description = "Complete BYOKConfig YAML for use with the BYOK CLI"
  value       = "# Auto-generated — do not edit manually.\n${yamlencode(local.byok_config)}"
}
