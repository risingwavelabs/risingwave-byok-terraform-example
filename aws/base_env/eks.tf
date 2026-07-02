# ------------------------------------------------------------------------------
# EKS Cluster for BYOK Test Environment
# ------------------------------------------------------------------------------

locals {
  eks_cluster_name = "${local.name_prefix}-eks"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.23.0"

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

  # Cluster addons
  addons = {
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
      service_account_role_arn = module.ebs_csi_irsa_role.arn
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

  # The vpc-cni addon above sets ENABLE_POD_ENI=true (Security Groups for Pods).
  # That makes the control-plane VPC Resource Controller attach a trunk ENI to
  # each node, which requires AmazonEKSVPCResourceController on the cluster IAM
  # role. The eks module only attaches AmazonEKSClusterPolicy by default, so
  # without this the controller fails with UnauthorizedOperation and emits
  # repeated TrunkENICreationFailed warnings.
  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  # Managed node group for Karpenter controller
  # Karpenter itself needs a static MNG (self-hosting would create a chicken-and-egg problem).
  # All other workloads are scheduled on Karpenter-managed NodePools (see k8s_addons).
  eks_managed_node_groups = {
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

  # Tag for Karpenter auto-discovery of the node security group
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

# EBS CSI Driver IRSA
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

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

# VPC CNI IRSA
module "vpc_cni_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

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
