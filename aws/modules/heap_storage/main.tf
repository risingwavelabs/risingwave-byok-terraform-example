# Customer-owned diagnostics storage and driver-level identity. Tenant and
# CloudAgent roles do not need heap-bucket permissions.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.0, < 7.0" }
  }
}

locals {
  oidc_issuer = split("oidc-provider/", var.oidc_provider_arn)[1]
  bucket_arn  = "arn:${split(":", var.oidc_provider_arn)[1]}:s3:::${var.bucket_name}"
}

resource "aws_s3_bucket" "heap" {
  bucket        = var.bucket_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "heap" {
  bucket                  = aws_s3_bucket.heap.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "heap" {
  bucket = aws_s3_bucket.heap.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "heap" {
  bucket = aws_s3_bucket.heap.id
  rule {
    id     = "heap-retention"
    status = "Enabled"
    filter { prefix = "heap/" }
    expiration { days = var.retention_days }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

resource "aws_iam_role" "driver" {
  name = var.role_name
  tags = var.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:s3-csi-driver-sa"
      } }
    }]
  })
}

resource "aws_iam_role_policy" "heap" {
  name = "heap-storage"
  role = aws_iam_role.driver.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = local.bucket_arn },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"], Resource = "${local.bucket_arn}/heap/*" },
    ]
  })
}
