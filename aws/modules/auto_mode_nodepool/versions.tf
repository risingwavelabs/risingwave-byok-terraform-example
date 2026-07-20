# EKS Auto Mode NodeClass/NodePool CRs are applied via alekc/kubectl, matching
# the OSS-Karpenter karpenter_nodepool module.
terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}
