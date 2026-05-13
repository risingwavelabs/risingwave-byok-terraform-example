# ------------------------------------------------------------------------------
# BYOK Tenant Resources
#
# Provisions per-tenant infrastructure for BYOK E2E testing:
#   1. RDS PostgreSQL instance (metastore)
#   2. IAM role with IRSA trust policy + S3 access (tenant workload identity)
#
# Reads base_env outputs (VPC, subnets, OIDC, S3) via terraform_remote_state.
# Tenant-specific inputs (namespace, service account) come from
# `rwc cluster describe` after phase-1 creation.
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = local.base_env.region
}

# ------------------------------------------------------------------------------
# Remote state: base_env
# ------------------------------------------------------------------------------
data "terraform_remote_state" "base_env" {
  backend = "local"
  config = {
    path = "${path.module}/../base_env/terraform.tfstate"
  }
}

locals {
  base_env    = data.terraform_remote_state.base_env.outputs
  name_prefix = local.base_env.name_prefix
  tags = merge(local.base_env.tags, var.tags, {
    Component = "byok-tenant-resources"
  })
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL (metastore)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "metastore" {
  name       = "${local.name_prefix}-metastore"
  subnet_ids = local.base_env.private_subnet_ids

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-metastore"
  })
}

resource "aws_security_group" "metastore" {
  name_prefix = "${local.name_prefix}-metastore-"
  vpc_id      = local.base_env.vpc_id
  description = "Allow PostgreSQL access from VPC"

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.base_env.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-metastore"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "metastore" {
  identifier = "${local.name_prefix}-metastore"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.rds_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.metastore.name
  vpc_security_group_ids = [aws_security_group.metastore.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-metastore"
  })
}

# ------------------------------------------------------------------------------
# IAM Role with IRSA trust policy + S3 access
# ------------------------------------------------------------------------------
locals {
  # Extract the OIDC provider ID from the full URL.
  # e.g. "https://oidc.eks.us-east-1.amazonaws.com/id/ABC123" → "oidc.eks.us-east-1.amazonaws.com/id/ABC123"
  oidc_provider = replace(local.base_env.eks_oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "tenant_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.base_env.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.tenant_namespace}:${var.tenant_service_account}"]
    }
  }
}

data "aws_iam_policy_document" "tenant_s3" {
  # RisingWave lays out cluster state under `data-<resource-namespace>/` and
  # meta backups under `data-<resource-namespace>-backup/` (the `data-` path
  # prefix is hard-coded for BYOK on AWS). Bucket-level actions
  # (ListBucket, GetBucketLocation) are scoped to the bucket itself; object
  # actions are scoped to the two tenant-owned prefixes only.
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      local.base_env.s3_bucket_arn,
      "${local.base_env.s3_bucket_arn}/data-${var.tenant_namespace}/*",
      "${local.base_env.s3_bucket_arn}/data-${var.tenant_namespace}-backup/*",
    ]
  }
}

resource "aws_iam_role" "tenant" {
  name               = "${local.name_prefix}-tenant"
  assume_role_policy = data.aws_iam_policy_document.tenant_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "tenant_s3" {
  name   = "s3-access"
  role   = aws_iam_role.tenant.id
  policy = data.aws_iam_policy_document.tenant_s3.json
}
