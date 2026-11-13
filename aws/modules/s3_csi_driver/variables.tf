variable "cluster_name" {
  type = string
}

variable "role_arn" {
  type        = string
  description = "IRSA role trusted by kube-system:s3-csi-driver-sa."
}

variable "addon_version" {
  type        = string
  description = "Mountpoint S3 CSI EKS add-on version; verify compatibility with the cluster's Kubernetes version."
  default     = "v2.6.0-eksbuild.1"
}

variable "controller_node_selector" {
  type    = map(string)
  default = {}
}

variable "controller_tolerations" {
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}
