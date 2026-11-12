mock_provider "aws" {}

variables {
  cluster_name = "byok-test"
  role_arn     = "arn:aws:iam::123456789012:role/byok-test-s3-csi"
}

run "driver_identity_and_untainted_system_nodes" {
  command = plan
  assert {
    condition     = aws_eks_addon.driver.addon_name == "aws-mountpoint-s3-csi-driver" && aws_eks_addon.driver.service_account_role_arn == var.role_arn && aws_eks_addon.driver.cluster_name == var.cluster_name && aws_eks_addon.driver.addon_version == "v2.6.0-eksbuild.1"
    error_message = "Install the pinned Mountpoint driver with its dedicated IRSA role."
  }
  assert {
    condition = jsondecode(aws_eks_addon.driver.configuration_values) == jsondecode(jsonencode({
      node       = { tolerateAllTaints = true }
      controller = { nodeSelector = {}, tolerations = [] }
    }))
    error_message = "The node daemon must tolerate all workload taints; the controller must use system scheduling settings."
  }
}

run "tainted_system_nodes" {
  command = plan
  variables {
    controller_node_selector = { workload = "system" }
    controller_tolerations   = [{ key = "dedicated", operator = "Equal", value = "system", effect = "NoSchedule" }]
  }
  assert {
    condition = jsondecode(aws_eks_addon.driver.configuration_values) == jsondecode(jsonencode({
      node = { tolerateAllTaints = true }
      controller = {
        nodeSelector = { workload = "system" }
        tolerations  = [{ key = "dedicated", operator = "Equal", value = "system", effect = "NoSchedule" }]
      }
    }))
    error_message = "Controller scheduling must follow the system node pool while node daemons still tolerate RW taints."
  }
}
