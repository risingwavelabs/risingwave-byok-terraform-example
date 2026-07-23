# ------------------------------------------------------------------------------
# EKS Cluster for BYOK Test Environment
#
# Supports two topologies via var.eks_auto_mode:
#   false (default) — standard cluster: coredns/kube-proxy/vpc-cni/ebs-csi
#                     addons, a Karpenter bootstrap managed node group, and OSS
#                     Karpenter NodePools (applied in k8s_addons).
#   true            — EKS Auto Mode with custom node pools: compute_config +
#                     create_auto_mode_iam_resources (Auto Mode manages the node
#                     IAM role and ships coredns/kube-proxy/vpc-cni/ebs-csi
#                     internally). The four addons, the Karpenter MNG,
#                     Security-Groups-for-Pods, and the ebs-csi/vpc-cni IRSA
#                     roles are all dropped; k8s_addons applies Auto Mode
#                     NodePools + eks.amazonaws.com/v1 NodeClasses instead.
# ------------------------------------------------------------------------------

locals {
  eks_cluster_name = "${local.name_prefix}-eks"

  # Standard-mode cluster addons. Auto Mode ships these components internally,
  # so it takes an empty addon set. The two drivers are mutually exclusive per
  # node type: standard uses in-tree kubernetes.io/aws-ebs (ebs.csi.aws.com via
  # CSI migration); Auto Mode uses the built-in ebs.csi.eks.amazonaws.com.
  eks_addons = var.eks_auto_mode ? {} : {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "node.kubernetes.io/not-ready"
            operator = "Exists"
            effect   = "NoSchedule"
          },
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          },
        ]
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = one(module.ebs_csi_irsa_role[*].arn)
      configuration_values = jsonencode({
        # The CSI Node DaemonSet must land on every node that can host a
        # pod with a PVC. Karpenter NodePools may carry workload taints
        # (system / cluster / telemetry / update), so tolerate any taint.
        # The controller is a Deployment that only runs on the bootstrap
        # karpenter MNG, so its toleration stays narrow.
        node       = { tolerations = [{ operator = "Exists" }] }
        controller = { tolerations = [{ key = "karpenter.sh/controller", value = "true", effect = "NoSchedule" }] }
      })
    }
  }

  # Bootstrap MNG that hosts the OSS Karpenter controller. Not needed in Auto
  # Mode, where AWS provisions all nodes from the custom NodePools.
  eks_managed_node_groups = var.eks_auto_mode ? {} : {
    karpenter = {
      name                           = "${local.name_prefix}-karpenter"
      iam_role_use_name_prefix       = false
      use_latest_ami_release_version = false # skip SSM:GetParameter (CI runners often lack this perm)
      instance_types                 = ["m7g.large"]
      ami_type                       = "AL2023_ARM_64_STANDARD"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = { "karpenter.sh/controller" = "true" }
      taints = {
        karpenter = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      subnet_ids = module.vpc.private_subnets

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            kms_key_id            = module.ebs_kms_key.key_arn
            delete_on_termination = true
          }
        }
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # The standard vpc-cni addon sets ENABLE_POD_ENI=true (Security Groups for
  # Pods), which makes the VPC Resource Controller attach a trunk ENI to each
  # node and requires AmazonEKSVPCResourceController on the cluster IAM role.
  # Auto Mode does not support SGP, so this policy is unnecessary there.
  eks_iam_role_additional_policies = var.eks_auto_mode ? {} : {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = local.eks_cluster_name
  kubernetes_version = var.kubernetes_version

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Disable EKS control-plane logging to CloudWatch.
  # BYOK environments deploy in-cluster observability (VictoriaMetrics + Loki
  # + Alloy) via k8s_addons as the system of record, so control-plane logs in
  # CloudWatch would be duplicate cost. cluster_enabled_log_types=[] stops the
  # cluster from emitting logs; create_cloudwatch_log_group=false prevents an
  # empty log group from being created at all. Operators who want CW logs can
  # override both — the module defaults flip the behavior back on.
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  # Allow the current user to administer the cluster
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode. compute_config.enabled toggles Auto Mode; with
  # create_auto_mode_iam_resources the module creates just the Auto Mode node
  # IAM role and leaves node provisioning to the custom
  # NodePools/NodeClasses in k8s_addons (no built-in general-purpose/system
  # pools). Standard mode passes enabled=false, matching the module default.
  create_auto_mode_iam_resources = var.eks_auto_mode
  compute_config = {
    enabled = var.eks_auto_mode
  }

  # Cluster addons (empty under Auto Mode — components are built in)
  addons = local.eks_addons

  iam_role_additional_policies = local.eks_iam_role_additional_policies

  # Managed node group for the Karpenter controller (standard mode only).
  # Karpenter itself needs a static MNG (self-hosting would create a
  # chicken-and-egg problem). All other workloads are scheduled on
  # Karpenter-managed NodePools (see k8s_addons).
  eks_managed_node_groups = local.eks_managed_node_groups

  # Tag for node security-group auto-discovery. Reused by both OSS Karpenter
  # EC2NodeClass and Auto Mode NodeClass securityGroupSelectorTerms.
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.eks_cluster_name
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = local.tags
}

# Custom Auto Mode NodeClasses require an EC2-type access entry for their node
# role plus AmazonEKSAutoNodePolicy. The EKS module creates this entry only for
# built-in NodePools; create_auto_mode_iam_resources alone creates the IAM role.
# https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html#create-node-class-access-entry
resource "aws_eks_access_entry" "auto_mode_node" {
  count = var.eks_auto_mode ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"

  tags = local.tags
}

resource "aws_eks_access_policy_association" "auto_mode_node" {
  count = var.eks_auto_mode ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.auto_mode_node]
}

# The two IRSA roles gained a count for the eks_auto_mode toggle. Migrate the
# existing (un-indexed) state to the [0] instance so standard-mode envs don't
# destroy/recreate their IRSA roles on upgrade.
moved {
  from = module.ebs_csi_irsa_role
  to   = module.ebs_csi_irsa_role[0]
}

moved {
  from = module.vpc_cni_irsa_role
  to   = module.vpc_cni_irsa_role[0]
}

# EBS CSI Driver IRSA (standard mode only — Auto Mode has a built-in EBS driver)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  count = var.eks_auto_mode ? 0 : 1

  name                  = "${local.name_prefix}-ebs-csi-irsa"
  policy_name           = "${local.name_prefix}-ebs-csi-irsa"
  use_name_prefix       = false
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# VPC CNI IRSA (standard mode only — Auto Mode has a built-in CNI)
module "vpc_cni_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  count = var.eks_auto_mode ? 0 : 1

  name                  = "${local.name_prefix}-vpc-cni-irsa"
  policy_name           = "${local.name_prefix}-vpc-cni-irsa"
  use_name_prefix       = false
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}
