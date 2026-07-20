# ------------------------------------------------------------------------------
# KMS Key for EBS Encryption
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.0"

  description = "KMS key for EBS encryption in BYOK test environment"

  # Allow the autoscaling service-linked role and EKS cluster role to use the
  # key for encrypted EBS volumes.
  key_service_roles_for_autoscaling = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    module.eks.cluster_iam_role_arn,
  ]

  # Auto Mode requires the cluster role to manage the complete lifecycle of
  # grants used for encrypted ephemeral node volumes.
  key_service_users = var.eks_auto_mode ? [module.eks.cluster_iam_role_arn] : []

  # Allow Karpenter-launched nodes to use encrypted EBS volumes
  # https://karpenter.sh/docs/troubleshooting/#node-terminates-before-ready-on-failed-encrypted-ebs-volume
  key_statements = [
    {
      sid    = "Allow access through EBS for all principals in the account that are authorized to use EBS"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey",
      ]
      resources = ["*"]
      condition = [
        {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["ec2.${var.region}.amazonaws.com"]
        },
        {
          test     = "StringEquals"
          variable = "kms:CallerAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
      ]
    },
    {
      sid    = "Allow direct access to key metadata to the account"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
      ]
      actions = [
        "kms:Describe*",
        "kms:Get*",
        "kms:List*",
        "kms:RevokeGrant",
      ]
      resources = ["*"]
    },
  ]

  # Key administrators
  key_administrators = [data.aws_iam_session_context.current.issuer_arn]

  # Aliases
  aliases = ["eks/${local.name_prefix}/ebs"]

  tags = local.tags
}
