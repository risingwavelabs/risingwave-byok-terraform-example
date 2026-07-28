variable "enabled" {
  description = "Whether the EKS cluster uses Auto Mode native load balancing."
  type        = bool
}

variable "cluster_name" {
  description = "EKS cluster name used to authorize native TargetGroupBinding reconciliation."
  type        = string
}

variable "target_ports" {
  description = "Target ports that Auto Mode NLBs and health checks must reach on pod ENIs."
  type        = map(number)
  default     = {}
}

variable "client_ports" {
  description = "NLB listener ports that direct clients must reach in Auto Mode."
  type        = map(number)
  default     = {}
}

variable "client_cidrs" {
  description = "CIDR blocks allowed to reach direct-client NLB listener ports in Auto Mode."
  type        = list(string)
  default     = []
}

output "target_group_tags" {
  description = "Tags required for target groups reconciled by EKS Auto Mode."
  value = var.enabled ? {
    "eks:eks-cluster-name" = var.cluster_name
  } : {}
}

output "nlb_security_group_required" {
  description = "Whether the pre-created NLBs require a security group."
  value       = var.enabled
}

output "private_link_security_group_enforcement" {
  description = "PrivateLink inbound security-group enforcement override for the NLBs."
  value       = var.enabled ? "off" : null
}

output "self_managed_controller_enabled" {
  description = "Whether to install the self-managed AWS Load Balancer Controller."
  value       = !var.enabled
}

output "node_security_group_ingress_ports" {
  description = "Target ports requiring explicit NLB-to-node security-group ingress because native TargetGroupBindings do not reconcile networking rules."
  value       = var.enabled ? var.target_ports : {}
}

output "nlb_client_ingress_rules" {
  description = "Deduplicated direct-client ingress rules required on the Auto Mode NLB security group."
  value = var.enabled ? {
    for pair in setproduct(values(var.client_ports), distinct(var.client_cidrs)) :
    "${pair[0]}:${pair[1]}" => {
      port = pair[0]
      cidr = pair[1]
    }
  } : {}
}
