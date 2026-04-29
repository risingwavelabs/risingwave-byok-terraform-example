################################################################################
# Controller & Node IAM roles, SQS Queue, Eventbridge Rules
################################################################################

module "karpenter_gear" {
  count = var.enabled ? 1 : 0

  source = "./gear"

  cluster_name                    = var.cluster_id
  namespace                       = var.karpenter_namespace
  irsa_service_account            = var.irsa_service_account
  irsa_oidc_provider_arn          = var.irsa_oidc_provider_arn
  additional_node_iam_policy_arns = var.additional_node_iam_policy_arns
  tags                            = var.tags
}

################################################################################
# Helm chart - Karpenter CRD
################################################################################

# https://karpenter.sh/docs/upgrading/upgrade-guide/#crd-upgrades
# https://medium.com/@takebsd/deploy-karpenter-v0-32-1-in-aws-eks-ba16dc550443

# NOTE:We already have Karpenter helm chart before, so when adding CRD now, we need to fix the ownership of the CRDs.
# https://karpenter.sh/docs/troubleshooting/#helm-error-when-installing-the-karpenter-crd-chart
# IMPORTANT: Remember to also patch nodeoverlays.karpenter.sh!!!
# https://github.com/aws/karpenter-provider-aws/issues/8908
# IMPORTANT: Do this for every env that goes from Karpenter helm chart -> Karpenter + Karpenter-CRD helm charts!!!

resource "helm_release" "karpenter_crd" {
  count = var.enabled ? 1 : 0

  name             = "karpenter-crd"
  namespace        = var.karpenter_namespace
  create_namespace = true
  repository       = var.use_private_helm_registry ? "${var.private_helm_registry}/karpenter" : "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_controller_chart_version
  timeout          = 1200
  atomic           = true

  depends_on = [module.karpenter_gear]
}

################################################################################
# Helm chart - Karpenter controller pods + linking roles + webhooks & CRD
# (CRD is only installed the first time the controller is deployed)
################################################################################

# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/70866e6fb26aa46a876f16567a043a9aaee4ed34/examples/karpenter/main.tf#L181-L183

resource "helm_release" "karpenter_controller" {
  count = var.enabled ? 1 : 0

  name             = "karpenter"
  namespace        = var.karpenter_namespace
  create_namespace = true
  repository       = var.use_private_helm_registry ? "${var.private_helm_registry}/karpenter" : "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_controller_chart_version
  timeout          = 1200
  atomic           = true

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    settings:
      clusterName: ${var.cluster_id}
      clusterEndpoint: ${var.cluster_endpoint}
      interruptionQueue: ${one(module.karpenter_gear[*].queue_name)}
      vmMemoryOverheadPercent: 0.015
    %{if var.use_private_container_registry}
      isolatedVPC: true
    %{endif}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${one(module.karpenter_gear[*].iam_role_arn)}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: karpenter.sh/controller
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
    %{if var.use_private_container_registry}
    controller:
      image:
        repository: ${var.private_container_registry}/karpenter/controller
    %{endif}
    EOT
  ]

  depends_on = [module.karpenter_gear, helm_release.karpenter_crd]
}
