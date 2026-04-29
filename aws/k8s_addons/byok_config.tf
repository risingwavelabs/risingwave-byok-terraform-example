# ------------------------------------------------------------------------------
# BYOKConfig YAML output
#
# Reads base_env outputs via terraform_remote_state, merges with k8s_addons
# scheduling data, and produces a complete BYOKConfig YAML matching the struct
# in risingwave-cloud/cli/operations/byok/config/types.go.
# ------------------------------------------------------------------------------

data "terraform_remote_state" "base_env" {
  backend = "local"
  config = {
    path = "${path.module}/../base_env/terraform.tfstate"
  }
}

locals {
  base_env = data.terraform_remote_state.base_env.outputs

  # --- Scheduling: convert nodepool taints → tolerations, labels → nodeAffinity ---

  system_tolerations = [for t in var.system_nodepool.taints : {
    key      = t.key
    operator = t.operator
    value    = t.value
    effect   = t.effect
  }]

  rw_tolerations = [for t in var.rw_nodepool.taints : {
    key      = t.key
    operator = t.operator
    value    = t.value
    effect   = t.effect
  }]

  system_node_affinity = length(var.system_nodepool.labels) > 0 ? {
    requiredDuringSchedulingIgnoredDuringExecution = {
      nodeSelectorTerms = [{
        matchExpressions = [for k, v in var.system_nodepool.labels : {
          key      = k
          operator = "In"
          values   = [v]
        }]
      }]
    }
  } : null

  rw_node_affinity = length(var.rw_nodepool.labels) > 0 ? {
    requiredDuringSchedulingIgnoredDuringExecution = {
      nodeSelectorTerms = [{
        matchExpressions = [for k, v in var.rw_nodepool.labels : {
          key      = k
          operator = "In"
          values   = [v]
        }]
      }]
    }
  } : null

  has_system_scheduling = length(var.system_nodepool.taints) > 0 || length(var.system_nodepool.labels) > 0
  has_rw_scheduling     = length(var.rw_nodepool.taints) > 0 || length(var.rw_nodepool.labels) > 0
  has_update_scheduling = length(var.update_nodepool.taints) > 0 || length(var.update_nodepool.labels) > 0

  system_workload = local.has_system_scheduling ? merge(
    length(local.system_tolerations) > 0 ? { tolerations = local.system_tolerations } : {},
    local.system_node_affinity != null ? { nodeAffinity = local.system_node_affinity } : {},
  ) : null

  cluster_workload = local.has_rw_scheduling ? merge(
    length(local.rw_tolerations) > 0 ? { tolerations = local.rw_tolerations } : {},
    local.rw_node_affinity != null ? { nodeAffinity = local.rw_node_affinity } : {},
  ) : null

  # --- Update workload scheduling (for BYOK terraform apply task pods) ---

  update_tolerations = [for t in var.update_nodepool.taints : {
    key      = t.key
    operator = t.operator
    value    = t.value
    effect   = t.effect
  }]

  update_node_affinity = length(var.update_nodepool.labels) > 0 ? {
    requiredDuringSchedulingIgnoredDuringExecution = {
      nodeSelectorTerms = [{
        matchExpressions = [for k, v in var.update_nodepool.labels : {
          key      = k
          operator = "In"
          values   = [v]
        }]
      }]
    }
  } : null

  update_workload = local.has_update_scheduling ? merge(
    length(local.update_tolerations) > 0 ? { tolerations = local.update_tolerations } : {},
    local.update_node_affinity != null ? { nodeAffinity = local.update_node_affinity } : {},
  ) : null

  # --- Telemetry workload scheduling (for VictoriaMetrics, Loki, Alloy) ---

  has_telemetry_scheduling = length(var.telemetry_nodepool.taints) > 0 || length(var.telemetry_nodepool.labels) > 0

  telemetry_tolerations = [for t in var.telemetry_nodepool.taints : {
    key      = t.key
    operator = t.operator
    value    = t.value
    effect   = t.effect
  }]

  telemetry_node_affinity = length(var.telemetry_nodepool.labels) > 0 ? {
    requiredDuringSchedulingIgnoredDuringExecution = {
      nodeSelectorTerms = [{
        matchExpressions = [for k, v in var.telemetry_nodepool.labels : {
          key      = k
          operator = "In"
          values   = [v]
        }]
      }]
    }
  } : null

  telemetry_workload = local.has_telemetry_scheduling ? merge(
    length(local.telemetry_tolerations) > 0 ? { tolerations = local.telemetry_tolerations } : {},
    local.telemetry_node_affinity != null ? { nodeAffinity = local.telemetry_node_affinity } : {},
  ) : null

  # system_daemonset is intentionally omitted — the CLI configwriter derives
  # DaemonSet node affinity automatically by merging system + cluster workload
  # affinities (CLOUD-4755).
  scheduling = (local.has_system_scheduling || local.has_rw_scheduling || local.has_update_scheduling || local.has_telemetry_scheduling) ? merge(
    local.system_workload != null ? { system_workload = local.system_workload } : {},
    local.cluster_workload != null ? { cluster_workload = local.cluster_workload } : {},
    local.update_workload != null ? { update_workload = local.update_workload } : {},
    local.telemetry_workload != null ? { telemetry_workload = local.telemetry_workload } : {},
  ) : null

  # Optional fields that live under customized_settings in the CLI BYOKConfig
  # struct (cli/operations/byox/byok/config/types.go — BYOKCustomizedSettings).
  # The schema nests scheduling / tags / metrics_settings, so we assemble them
  # here and only attach when at least one sub-field is present.
  customized_settings_entries = merge(
    local.scheduling != null ? { scheduling = local.scheduling } : {},
    length(local.base_env.tags) > 0 ? { tags = local.base_env.tags } : {},
  )

  # --- Assemble the complete BYOKConfig ---

  byok_config = merge(
    {
      cloud_provider = "aws"
      region         = local.base_env.region
      aws = {
        account_id       = local.base_env.aws_account_id
        eks_cluster_name = local.base_env.eks_cluster_name
        s3_buckets = {
          data_store_arn = local.base_env.s3_bucket_arn
          log_store_arn  = local.base_env.loki_s3_bucket_arn
        }
        ebs_encryption_key_arn = local.base_env.ebs_encryption_key_arn
        iam_roles = {
          cloudagent_role_arn = local.base_env.cloudagent_role_arn
          loki_role_arn       = local.base_env.loki_role_arn
        }
        network_load_balancers = {
          cloudagent_target_group_arn          = local.base_env.cloudagent_target_group_arn
          cloudagent_zpage_target_group_arn    = local.base_env.cloudagent_zpage_target_group_arn
          rwproxy_target_group_arn             = local.base_env.rwproxy_internal_target_group_arn
          rwproxy_webhook_target_group_arn     = local.base_env.rwproxy_webhook_target_group_arn
          rwproxy_metrics_target_group_arn     = local.base_env.rwproxy_metrics_target_group_arn
          cloudagent_subnet_cidrs              = local.base_env.private_subnet_cidrs
          rwproxy_subnet_cidrs                 = local.base_env.private_subnet_cidrs
          cloudagent_vpc_endpoint_service_name = local.base_env.cloudagent_vpc_endpoint_service_name
          rwproxy_vpc_endpoint_service_name    = local.base_env.rwproxy_vpc_endpoint_service_name
        }
        terraform_state = {
          s3_bucket_name      = local.base_env.terraform_state_s3_bucket_name
          dynamodb_table_name = local.base_env.terraform_lock_dynamodb_table_name
        }
      }
    },
    length(local.customized_settings_entries) > 0 ? { customized_settings = local.customized_settings_entries } : {},
  )
}
