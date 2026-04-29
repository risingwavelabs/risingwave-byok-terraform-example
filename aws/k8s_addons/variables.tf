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
variable "system_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.large", "m7g.xlarge"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the system workloads Karpenter NodePool."
  default     = {}
}

variable "rw_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.xlarge", "m7g.2xlarge"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the RisingWave workloads Karpenter NodePool."
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
  description = "Configuration for the BYOK update task Karpenter NodePool (terraform apply jobs)."
  default     = {}
}

variable "telemetry_nodepool" {
  type = object({
    instance_types = optional(list(string), ["m7g.large", "m7g.xlarge"])
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key      = string
      operator = optional(string, "Equal")
      value    = string
      effect   = string
    })), [])
    cpu_limit = optional(string, "")
  })
  description = "Configuration for the self-hosted telemetry Karpenter NodePool (VictoriaMetrics, Loki, Alloy)."
  default     = {}
}
