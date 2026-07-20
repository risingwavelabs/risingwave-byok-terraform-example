################################################################################
# EKS Auto Mode NodeClass + NodePool
#
# Auto Mode counterpart of ../karpenter_nodepool. It renders the SAME NodePool
# (karpenter.sh/v1) — identical labels/taints/instance-types/disruption — but
# points nodeClassRef at an eks.amazonaws.com/v1 NodeClass instead of an OSS
# karpenter.k8s.aws/v1 EC2NodeClass. Auto Mode manages the AMI/bootstrap, so the
# NodeClass has no amiFamily/blockDeviceMappings/metadataOptions; disk is set via
# a single ephemeralStorage volume instead.
#
# NodeClass: https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html
# NodePool:  https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html
################################################################################

locals {
  nodeclass_name = "${var.name}-nodeclass"

  # Only render ephemeralStorage sub-fields that are set, so AWS defaults apply
  # for iops/throughput and encryption is opt-in via kms_key_id.
  ephemeral_storage = merge(
    { size = var.ephemeral_storage.size },
    var.ephemeral_storage.iops != null ? { iops = var.ephemeral_storage.iops } : {},
    var.ephemeral_storage.throughput != null ? { throughput = var.ephemeral_storage.throughput } : {},
    var.ephemeral_storage.kms_key_id != null ? { kmsKeyID = var.ephemeral_storage.kms_key_id } : {},
  )

  nodeclass = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = local.nodeclass_name
    }
    spec = {
      role = var.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "${var.subnet_tag_key}" = var.cluster_id
          }
        }
      ]
      securityGroupSelectorTerms = concat(
        [
          {
            tags = {
              "karpenter.sh/discovery" = var.cluster_id
            }
          }
        ],
        [for sg_id in var.additional_security_group_ids : { id = sg_id }]
      )
      ephemeralStorage = local.ephemeral_storage
    }
  }
}

resource "kubectl_manifest" "nodeclass" {
  count = var.enabled ? 1 : 0

  yaml_body = yamlencode(local.nodeclass)
  wait      = true
}

locals {
  nodepool_template_nodeclassref = {
    nodeClassRef = {
      group = "eks.amazonaws.com"
      kind  = "NodeClass"
      name  = local.nodeclass_name
    }
  }
  nodepool_template_requirements = {
    requirements = [
      {
        key      = "node.kubernetes.io/instance-type"
        operator = "In"
        values   = var.instance_types
      },
      {
        key      = "karpenter.sh/capacity-type"
        operator = "In"
        values   = var.capacity_types
      }
    ]
  }
  nodepool_template_taints = length(var.taints) > 0 ? {
    taints = var.taints
  } : {}
  nodepool_template_expire_after = var.expire_after != null ? {
    expireAfter = var.expire_after
  } : {}

  nodepool_template = {
    template = {
      metadata = {
        labels = var.labels
      }
      spec = merge(
        local.nodepool_template_nodeclassref,
        local.nodepool_template_requirements,
        local.nodepool_template_taints,
        local.nodepool_template_expire_after,
      )
    }
  }
  nodepool_limits = var.cpu_limit != "" ? {
    limits = {
      cpu = var.cpu_limit
    }
  } : {}
  nodepool_disruption = {
    disruption = var.disruption
  }

  nodepool = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = var.name
    }
    spec = merge(
      local.nodepool_template,
      local.nodepool_limits,
      local.nodepool_disruption
    )
  }
}

resource "kubectl_manifest" "nodepool" {
  count = var.enabled ? 1 : 0

  # The NodePool references the NodeClass by name; apply the NodeClass first.
  yaml_body  = yamlencode(local.nodepool)
  wait       = true
  depends_on = [kubectl_manifest.nodeclass]
}
