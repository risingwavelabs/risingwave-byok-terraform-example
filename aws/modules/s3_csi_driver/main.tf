terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.0, < 7.0" }
  }
}

resource "aws_eks_addon" "driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-mountpoint-s3-csi-driver"
  addon_version            = var.addon_version
  service_account_role_arn = var.role_arn
  # Fail on conflicts with an existing installation instead of taking it over.
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "NONE"
  configuration_values = jsonencode({
    node = { tolerateAllTaints = true }
    controller = {
      nodeSelector = var.controller_node_selector
      tolerations  = var.controller_tolerations
    }
  })
}
