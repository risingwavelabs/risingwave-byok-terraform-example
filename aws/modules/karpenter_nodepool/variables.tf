variable "enabled" {
  description = "Whether to enable AWS Karpenter - node pool configurations."
  type        = bool
  default     = true
}

variable "cluster_id" {
  description = "The name/id of the EKS cluster."
  type        = string
}

variable "node_iam_role_name" {
  description = "Node IAM role name from the Karpenter submodule."
  type        = string
}

variable "name" {
  description = "Name of the Karpenter node pool to be created."
  type        = string
}

variable "ami_family" {
  description = "AMI family to use for the node pool."
  type        = string
}

variable "ami_version" {
  description = "AMI version to use for the node pool. It is not recommended to use the latest version for production environments."
  type        = string
}

variable "instance_types" {
  description = "Amazon EC2 Instance Types: https://aws.amazon.com/ec2/instance-types/."
  type        = list(string)
}

# priority: reserved -> spot -> on-demand
variable "capacity_types" {
  description = "Amazon EC2 Purchase Options: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-purchasing-options.html."
  type        = list(string)
  default     = ["on-demand"]
}

variable "labels" {
  description = "Arbitrary key/value pairs to apply to all nodes."
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

variable "subnet_id" {
  description = "Subnet utilized by this specific node pool with a EC2 Node Class."
  type        = string
  default     = ""
}

variable "subnet_tag_key" {
  description = "Key of the tag added to the subnets for Karpenter auto-discovery (default to the one from Karpenter's doc unless customized here)."
  type        = string
  default     = "karpenter.sh/discovery"
}

variable "cpu_limit" {
  description = "CPU limits are described with a DecimalSI value. Note that the Kubernetes API will coerce this into a string, so we recommend against using integers to avoid GitOps skew."
  type        = string
  default     = ""
}

variable "block_device_mappings" {
  description = "EBS volumns attached to the provisioned nodes: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/block-device-mapping-concepts.html#instance-block-device-mapping."
  type = list(object({
    device_name = string
    ebs = object({
      volume_size           = string # e.g., 100Gi
      volume_type           = string
      encrypted             = bool
      kms_key_id            = optional(string)
      delete_on_termination = bool
    })
  }))
  default = []
}

# https://karpenter.sh/docs/concepts/nodepools/#specdisruption
# https://karpenter.sh/docs/concepts/disruption/#nodepool-disruption-budgets
variable "disruption" {
  description = "Disruption settings for the node pool. Overrides disruption_max_unavailable_percentage."
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
  description = "The amount of time a Node can live on the cluster before being deleted by Karpenter."
  type        = string
  default     = "Never"
}

variable "bootstrap_extra_args" {
  description = "User data applied to the worker nodes for custom scripts / start-up configurations: https://karpenter.sh/docs/concepts/nodeclasses/#specuserdata"
  type        = string
  default     = ""
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to include in the EC2NodeClass securityGroupSelectorTerms. Useful when external systems (e.g., AWS Firewall Manager) attach extra security groups to instances, which would otherwise cause Karpenter SecurityGroupDrift."
  type        = list(string)
  default     = []
}

variable "disable_associate_public_ip_address" {
  description = "If true, explicitly disable public IP address association on network interfaces for launched instances."
  type        = bool
  default     = false
}
