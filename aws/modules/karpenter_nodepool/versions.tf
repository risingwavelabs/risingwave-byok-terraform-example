# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter?tab=dependencies
terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}
