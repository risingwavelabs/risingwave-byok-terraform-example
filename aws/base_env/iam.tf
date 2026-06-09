# ------------------------------------------------------------------------------
# IAM Roles for BYOK Components (with IRSA trust policies)
# - CloudAgent IAM: S3 access, AMP query
# - Metrics Scraper IAM (Grafana Agent): AMP remote write
# - Logs Scraper IAM (Fluent Bit): CloudWatch logs write
# - Telemetry Access IAM: For RisingWave support team access
# ------------------------------------------------------------------------------

locals {
  cloudagent_namespace       = "rw-cloudagent"
  cloudagent_service_account = "cloudagent"
}

# ------------------------------------------------------------------------------
# CloudAgent IAM Role
# Permissions: S3 access for object store, AMP query for metrics
# ------------------------------------------------------------------------------
module "cloudagent_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  name            = "${local.name_prefix}-cloudagent-irsa"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.cloudagent_namespace}:${local.cloudagent_service_account}"]
    }
  }

  tags = local.tags
}

resource "aws_iam_role_policy" "cloudagent_s3" {
  name = "${local.name_prefix}-cloudagent-s3"
  role = module.cloudagent_irsa_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.risingwave_data.arn,
          "${aws_s3_bucket.risingwave_data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudagent_tfstate" {
  name = "${local.name_prefix}-cloudagent-tfstate"
  role = module.cloudagent_irsa_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "dynamodb:*"
        Resource = aws_dynamodb_table.terraform_lock.arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# Loki (Hosted Telemetry) IAM Role
# Permissions: S3 access for Loki log storage
# ------------------------------------------------------------------------------
module "loki_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  name            = "${local.name_prefix}-loki-irsa"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["rw-loki:loki"]
    }
  }

  tags = local.tags
}

resource "aws_iam_role_policy" "loki_s3" {
  name = "${local.name_prefix}-loki-s3"
  role = module.loki_irsa_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.loki_logs.arn,
          "${aws_s3_bucket.loki_logs.arn}/*"
        ]
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role
# Required for NLB/ALB provisioning in BYOK
# ------------------------------------------------------------------------------
module "aws_lb_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  name                                   = "${local.name_prefix}-aws-lb-controller-irsa"
  policy_name                            = "${local.name_prefix}-aws-lb-controller-irsa"
  use_name_prefix                        = false
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

# Telemetry Access IAM Role is not needed with hosted telemetry —
# the support team accesses metrics/logs via the admin service proxy.
