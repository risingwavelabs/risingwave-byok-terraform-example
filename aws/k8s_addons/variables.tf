# Provider configuration — these two are needed by the aws provider and
# data.aws_eks_cluster, which cannot reference data source outputs.
# All other base_env values are read via terraform_remote_state in byok_config.tf.
variable "region" {
  type        = string
  description = "AWS region where the EKS cluster is located."
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster."
}

# Chart versions (aligned with aws/modules/resource_versions)
variable "cert_manager_version" {
  type        = string
  description = "cert-manager Helm chart version (v1.18.2+ required per BYOK spec)."
  default     = "v1.19.2"
}

variable "aws_lb_controller_version" {
  type        = string
  description = "AWS Load Balancer Controller Helm chart version."
  default     = "1.17.0"
}

variable "karpenter_version" {
  type        = string
  description = "Karpenter Helm chart version."
  default     = "1.8.3"
}

# Karpenter NodePool configurations
#
# Default instance_types mirror the recommended BYOC node pools in
# terraform-risingwave-cloud-byoc (aws/k8s_resources/karpenter_nodepool_spec.tf):
#
#   system_nodepool    ← dm-2v8g-nonsys (2c8g)
#   rw_nodepool        ← front-1c4m     (1:4 CPU:memory, 2c8g → 64c256g)
#   telemetry_nodepool ← hosted-telemetry (4c16g)
#   update_nodepool    ← byoc-gen-8c32g  (8c32g)
#
# See terraform.tfvars.example for the full recommended configuration including
# labels, taints, and cpu_limit for each pool.
variable "system_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.large"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the system workloads Karpenter NodePool (CloudAgent, RWProxy, monitoring). Mirrors BYOC dm-2v8g-nonsys."
  default     = {}
}

variable "rw_nodepool" {
  type = object({
    instance_types = optional(list(string), [
      "m7g.large",    # 2c8g
      "m7g.xlarge",   # 4c16g
      "m7g.2xlarge",  # 8c32g
      "m7g.4xlarge",  # 16c64g
      "m7g.8xlarge",  # 32c128g
      "m7g.12xlarge", # 48c192g
      "m7g.16xlarge", # 64c256g
    ])
    labels = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the RisingWave workloads Karpenter NodePool. Mirrors BYOC front-1c4m (1:4 CPU:memory ratio)."
  default     = {}
}

variable "update_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.2xlarge"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the BYOK update task Karpenter NodePool (terraform apply jobs). Mirrors BYOC byoc-gen-8c32g."
  default     = {}
}

variable "telemetry_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.xlarge"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the self-hosted telemetry Karpenter NodePool (VictoriaMetrics, Loki, Alloy). Mirrors BYOC hosted-telemetry."
  default     = {}
}
