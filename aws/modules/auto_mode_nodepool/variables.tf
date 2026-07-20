variable "enabled" {
  description = "Whether to create the EKS Auto Mode NodeClass + NodePool."
  type        = bool
  default     = true
}

variable "cluster_id" {
  description = "The name/id of the EKS cluster (used for karpenter.sh/discovery subnet & security-group selectors)."
  type        = string
}

variable "node_iam_role_name" {
  description = "EKS Auto Mode node IAM role name (module.eks.node_iam_role_name). Becomes NodeClass.spec.role."
  type        = string
}

variable "name" {
  description = "Name of the NodePool to create. The NodeClass is named <name>-nodeclass."
  type        = string
}

variable "instance_types" {
  description = "Amazon EC2 instance types the NodePool may provision."
  type        = list(string)
}

# priority: reserved -> spot -> on-demand
variable "capacity_types" {
  description = "Amazon EC2 purchase options (karpenter.sh/capacity-type)."
  type        = list(string)
  default     = ["on-demand"]
}

variable "labels" {
  description = "Labels applied to all nodes provisioned by this NodePool."
  type        = map(string)
}

# defaults to [] for yamlencode
variable "taints" {
  description = "Taints to add to provisioned nodes."
  type = list(object({
    key      = string
    operator = optional(string, "Equal")
    value    = string
    effect   = string
  }))
  default = []
}

variable "cpu_limit" {
  description = "NodePool CPU limit (DecimalSI string). Empty string means no limit."
  type        = string
  default     = ""
}

# Auto Mode uses a single ephemeralStorage volume on the NodeClass instead of
# the OSS EC2NodeClass blockDeviceMappings.
# https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html
variable "ephemeral_storage" {
  description = "EKS Auto Mode node ephemeral storage. size is required; iops/throughput/kms_key_id are optional (AWS defaults apply when omitted)."
  type = object({
    size       = optional(string, "80Gi")
    iops       = optional(number)
    throughput = optional(number)
    kms_key_id = optional(string)
  })
  default = {}
}

variable "subnet_tag_key" {
  description = "Tag key used to discover subnets for the NodeClass subnetSelectorTerms."
  type        = string
  default     = "karpenter.sh/discovery"
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to include in the NodeClass securityGroupSelectorTerms."
  type        = list(string)
  default     = []
}

# https://karpenter.sh/docs/concepts/nodepools/#specdisruption
variable "disruption" {
  description = "Disruption settings for the NodePool."
  type = object({
    consolidationPolicy = optional(string)
    consolidateAfter    = optional(string)
    budgets = optional(list(object({
      nodes    = optional(string)
      schedule = optional(string)
      duration = optional(string)
      reasons  = optional(list(string))
    })))
  })
  default = {}
}

# https://karpenter.sh/docs/concepts/nodepools/#spectemplatespecexpireafter
variable "expire_after" {
  description = "How long an Auto Mode node may live before deletion. Null uses the EKS default (336h). Auto Mode does not support Never."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.expire_after == null || var.expire_after != "Never"
    error_message = "expire_after cannot be \"Never\" for an EKS Auto Mode NodePool; use null for the EKS default (336h)."
  }
}
