# ------------------------------------------------------------------------------
# Kubernetes Add-ons for BYOK Test Environment
# - Karpenter (dynamic node provisioning)
# - cert-manager (v1.18.2+ required per BYOK spec)
# - AWS Load Balancer Controller (required for NLB provisioning)
#
# Deployment order:
#   Karpenter controller → NodePools → cert-manager → AWS LB Controller
#
# Karpenter runs on the dedicated tainted MNG. Once NodePools are applied,
# Karpenter provisions untainted nodes for everything else.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Karpenter — dynamic node provisioning
# ------------------------------------------------------------------------------

locals {
  # Bottlerocket block device mappings for Karpenter NodePools
  # https://github.com/bottlerocket-os/bottlerocket#default-volumes
  bottlerocket_block_device_mappings = [
    {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = "2Gi"
        volume_type           = "gp3"
        encrypted             = true
        kms_key_id            = local.base_env.ebs_encryption_key_arn
        delete_on_termination = true
      }
    },
    {
      device_name = "/dev/xvdb"
      ebs = {
        volume_size           = "50Gi"
        volume_type           = "gp3"
        encrypted             = true
        kms_key_id            = local.base_env.ebs_encryption_key_arn
        delete_on_termination = true
      }
    },
  ]

  default_disruption = {
    consolidationPolicy = "WhenEmptyOrUnderutilized"
    consolidateAfter    = "30s"
    budgets             = [{ nodes = "60%", reasons = ["Empty", "Drifted", "Underutilized"] }]
  }

  # Single source of truth: base_env decides the cluster topology and exposes it.
  # try() keeps k8s_addons working against base_env states applied before the
  # eks_auto_mode output existed (defaults to standard OSS-Karpenter).
  eks_auto_mode          = try(local.base_env.eks_auto_mode, false)
  eks_node_iam_role_name = try(local.base_env.eks_node_iam_role_name, "")

  # Auto Mode uses one ephemeralStorage volume per node (vs. the OSS
  # blockDeviceMappings), encrypted with the same EBS KMS key.
  auto_mode_ephemeral_storage = {
    size       = "80Gi"
    kms_key_id = local.base_env.ebs_encryption_key_arn
  }

  # Tolerations for pre-BYOK add-ons (cert-manager, AWS LB Controller) that must
  # land on system nodes when the system Karpenter NodePool has taints. Derived
  # from var.system_nodepool.taints so the tolerations stay in sync with whatever
  # taints the user configures — empty list when the nodepool is untainted.
  system_node_tolerations = [for t in var.system_nodepool.taints : {
    key      = t.key
    operator = t.operator
    value    = t.value
    effect   = t.effect
  }]
}

# Karpenter controller (IAM, SQS, EventBridge, Helm chart)
# Deploys first — runs on the dedicated tainted MNG (tolerates its own taint).
module "karpenter" {
  source = "../modules/karpenter"

  enabled          = !local.eks_auto_mode
  cluster_id       = var.eks_cluster_name
  cluster_endpoint = local.base_env.eks_cluster_endpoint

  karpenter_namespace                = "karpenter"
  irsa_service_account               = "karpenter"
  irsa_oidc_provider_arn             = local.base_env.eks_oidc_provider_arn
  karpenter_controller_chart_version = var.karpenter_version

  additional_node_iam_policy_arns = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = { Project = "RisingWave-BYOK-Test" }
}

# System NodePool — for system workloads (CloudAgent, RWProxy, monitoring, etc.)
module "nodepool_system" {
  source = "../modules/karpenter_nodepool"

  enabled            = !local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = module.karpenter.karpenter_node_iam_role_name
  name               = "system"
  ami_family         = "Bottlerocket"
  ami_version        = "bottlerocket@v1.54.0"
  instance_types     = var.system_nodepool.instance_types
  labels             = var.system_nodepool.labels
  taints             = var.system_nodepool.taints
  cpu_limit          = var.system_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  block_device_mappings = local.bottlerocket_block_device_mappings
  disruption            = local.default_disruption

  depends_on = [module.karpenter]
}

# RW NodePool — for RisingWave workloads
module "nodepool_rw" {
  source = "../modules/karpenter_nodepool"

  enabled            = !local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = module.karpenter.karpenter_node_iam_role_name
  name               = "rw"
  ami_family         = "Bottlerocket"
  ami_version        = "bottlerocket@v1.54.0"
  instance_types     = var.rw_nodepool.instance_types
  labels             = var.rw_nodepool.labels
  taints             = var.rw_nodepool.taints
  cpu_limit          = var.rw_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  block_device_mappings = local.bottlerocket_block_device_mappings
  disruption            = local.default_disruption

  depends_on = [module.karpenter]
}

# Update NodePool — for BYOK update task pods (terraform apply jobs).
# Uses m7g.2xlarge (8 vCPU, 32 GiB) to avoid OOM during updates with full
# telemetry stack.
module "nodepool_update" {
  source = "../modules/karpenter_nodepool"

  enabled            = !local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = module.karpenter.karpenter_node_iam_role_name
  name               = "update"
  ami_family         = "Bottlerocket"
  ami_version        = "bottlerocket@v1.54.0"
  instance_types     = var.update_nodepool.instance_types
  labels             = var.update_nodepool.labels
  taints             = var.update_nodepool.taints
  cpu_limit          = var.update_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  block_device_mappings = local.bottlerocket_block_device_mappings
  disruption            = local.default_disruption

  depends_on = [module.karpenter]
}

# Telemetry NodePool — for self-hosted telemetry workloads (VictoriaMetrics, Loki, Alloy)
module "nodepool_telemetry" {
  source = "../modules/karpenter_nodepool"

  enabled            = !local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = module.karpenter.karpenter_node_iam_role_name
  name               = "telemetry"
  ami_family         = "Bottlerocket"
  ami_version        = "bottlerocket@v1.54.0"
  instance_types     = var.telemetry_nodepool.instance_types
  labels             = var.telemetry_nodepool.labels
  taints             = var.telemetry_nodepool.taints
  cpu_limit          = var.telemetry_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  block_device_mappings = local.bottlerocket_block_device_mappings
  disruption            = local.default_disruption

  depends_on = [module.karpenter]
}

# ------------------------------------------------------------------------------
# EKS Auto Mode NodePools + NodeClasses (var eks_auto_mode = true)
#
# Auto Mode counterparts of the four OSS Karpenter NodePools above — same names,
# labels, taints, instance types, cpu limits, and disruption — but backed by
# eks.amazonaws.com/v1 NodeClasses and the Auto-Mode-managed node IAM role. AWS
# manages the AMI/bootstrap, so there is no Karpenter controller/MNG. Disk comes
# from a single encrypted ephemeralStorage volume instead of blockDeviceMappings.
# ------------------------------------------------------------------------------

module "auto_mode_nodepool_system" {
  source = "../modules/auto_mode_nodepool"

  enabled            = local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = local.eks_node_iam_role_name
  name               = "system"
  instance_types     = var.system_nodepool.instance_types
  labels             = var.system_nodepool.labels
  taints             = var.system_nodepool.taints
  cpu_limit          = var.system_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  ephemeral_storage = local.auto_mode_ephemeral_storage
  disruption        = local.default_disruption
}

module "auto_mode_nodepool_rw" {
  source = "../modules/auto_mode_nodepool"

  enabled            = local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = local.eks_node_iam_role_name
  name               = "rw"
  instance_types     = var.rw_nodepool.instance_types
  labels             = var.rw_nodepool.labels
  taints             = var.rw_nodepool.taints
  cpu_limit          = var.rw_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  ephemeral_storage = local.auto_mode_ephemeral_storage
  disruption        = local.default_disruption
}

module "auto_mode_nodepool_update" {
  source = "../modules/auto_mode_nodepool"

  enabled            = local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = local.eks_node_iam_role_name
  name               = "update"
  instance_types     = var.update_nodepool.instance_types
  labels             = var.update_nodepool.labels
  taints             = var.update_nodepool.taints
  cpu_limit          = var.update_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  ephemeral_storage = local.auto_mode_ephemeral_storage
  disruption        = local.default_disruption
}

module "auto_mode_nodepool_telemetry" {
  source = "../modules/auto_mode_nodepool"

  enabled            = local.eks_auto_mode
  cluster_id         = var.eks_cluster_name
  node_iam_role_name = local.eks_node_iam_role_name
  name               = "telemetry"
  instance_types     = var.telemetry_nodepool.instance_types
  labels             = var.telemetry_nodepool.labels
  taints             = var.telemetry_nodepool.taints
  cpu_limit          = var.telemetry_nodepool.cpu_limit
  capacity_types     = ["on-demand"]

  ephemeral_storage = local.auto_mode_ephemeral_storage
  disruption        = local.default_disruption
}

# ------------------------------------------------------------------------------
# Helm add-ons — deploy after Karpenter NodePools.
#
# When the system Karpenter NodePool is tainted (var.system_nodepool.taints),
# these charts need explicit tolerations to land on system nodes — they have
# no built-in tolerations and no pod-level nodeSelector, so without this fix
# they stay Pending because every nodepool Karpenter can provision is tainted.
#
# local.system_node_tolerations is derived from var.system_nodepool.taints
# and fed via a `values` yamlencode block. When the nodepool is untainted the
# list is empty and the `values` block is a no-op, preserving the pre-existing
# default behavior.
# ------------------------------------------------------------------------------

# cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  timeout          = 1200
  atomic           = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "cert-manager"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
  ]

  # Each cert-manager component has its own tolerations block. Apply the
  # system-node tolerations to all four so every pod can schedule.
  values = [yamlencode({
    tolerations = local.system_node_tolerations
    webhook = {
      tolerations = local.system_node_tolerations
    }
    cainjector = {
      tolerations = local.system_node_tolerations
    }
    startupapicheck = {
      tolerations = local.system_node_tolerations
    }
  })]

  # Wait for whichever set of nodepools is active (OSS or Auto Mode) so
  # cert-manager pods have somewhere to schedule.
  depends_on = [
    module.nodepool_system,
    module.nodepool_rw,
    module.auto_mode_nodepool_system,
    module.auto_mode_nodepool_rw,
  ]
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lb_controller_version
  timeout    = 1200
  atomic     = true

  set = [
    {
      name  = "clusterName"
      value = var.eks_cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = local.base_env.aws_lb_controller_role_arn
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = local.base_env.vpc_id
    },
  ]

  values = [yamlencode({
    tolerations = local.system_node_tolerations
  })]

  depends_on = [helm_release.cert_manager]
}
