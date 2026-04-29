################################################################################
# kubectl_manifest Karpenter scaling rules for controller pods
# YAML Encoding: https://developer.hashicorp.com/terraform/language/functions/templatefile#generating-json-or-yaml-from-a-template
# NodeClass: https://karpenter.sh/docs/concepts/nodeclasses/
# NodePools: https://karpenter.sh/docs/concepts/nodepools/

################################################################################

locals {
  ec2nodeclass_name = "${var.name}-ec2nodeclass"
  subnetSelectorTerms = [
    merge(
      var.subnet_id == "" ?
      {
        tags = {
          "${var.subnet_tag_key}" = var.cluster_id
        }
      } : {},
      var.subnet_id != "" ?
      {
        id = var.subnet_id
      } : {}
    )
  ]
}

locals {
  ec2nodeclass_basics = {
    amiFamily = var.ami_family
    amiSelectorTerms = [
      {
        alias = var.ami_version
      }
    ]
    role                = var.node_iam_role_name
    subnetSelectorTerms = local.subnetSelectorTerms
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
    tags = {
      "karpenter.sh/discovery" = var.cluster_id
    }
  }
  ec2nodeclass_user_data = var.bootstrap_extra_args != "" ? {
    userData = var.bootstrap_extra_args
  } : {}
  ec2nodeclass_block_dev_mappings = length(var.block_device_mappings) > 0 ? {
    blockDeviceMappings = [
      for i in range(length(var.block_device_mappings)) : {
        deviceName = var.block_device_mappings[i].device_name
        ebs = {
          volumeSize          = var.block_device_mappings[i].ebs.volume_size
          volumeType          = var.block_device_mappings[i].ebs.volume_type
          encrypted           = var.block_device_mappings[i].ebs.encrypted
          kmsKeyID            = var.block_device_mappings[i].ebs.kms_key_id
          deleteOnTermination = var.block_device_mappings[i].ebs.delete_on_termination
        }
      }
    ]
  } : {}
  ec2nodeclass_meta_opt = {
    metadataOptions = {
      httpEndpoint            = "enabled"
      httpProtocolIPv6        = "disabled"
      httpPutResponseHopLimit = 3
      httpTokens              = "required"
    }
  }
  ec2nodeclass_associate_public_ip = var.disable_associate_public_ip_address ? {
    associatePublicIPAddress = false
  } : {}
}

locals {
  ec2nodeclass = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = local.ec2nodeclass_name
    }
    spec = merge(
      local.ec2nodeclass_basics,
      local.ec2nodeclass_user_data,
      local.ec2nodeclass_block_dev_mappings,
      local.ec2nodeclass_meta_opt,
      local.ec2nodeclass_associate_public_ip
    )
  }
}

resource "kubectl_manifest" "ec2nodeclass" {
  count = var.enabled ? 1 : 0

  yaml_body = yamlencode(local.ec2nodeclass)
  wait      = true
}

locals {
  nodepool_template_nodeclassref = {
    nodeClassRef = {
      group = "karpenter.k8s.aws"
      kind  = "EC2NodeClass"
      name  = local.ec2nodeclass_name
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
}

locals {
  nodepool_template = {
    template = {
      metadata = {
        labels = var.labels
      }
      spec = merge(
        local.nodepool_template_nodeclassref,
        local.nodepool_template_requirements,
        local.nodepool_template_taints,
        {
          expireAfter = var.expire_after
        }
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
}

locals {
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

  yaml_body = yamlencode(local.nodepool)
  wait      = true
}
