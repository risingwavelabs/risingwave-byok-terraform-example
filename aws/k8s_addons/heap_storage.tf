# Install after node provisioning, including Auto Mode's customer NodePools.
module "s3_csi_driver" {
  source = "../modules/s3_csi_driver"

  cluster_name             = var.eks_cluster_name
  role_arn                 = local.base_env.heap_csi_role_arn
  addon_version            = var.s3_csi_driver_version
  controller_node_selector = var.system_nodepool.labels
  controller_tolerations   = local.system_node_tolerations

  depends_on = [module.nodepool_system, module.auto_mode_nodepool_system]
}
