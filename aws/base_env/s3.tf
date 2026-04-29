# ------------------------------------------------------------------------------
# S3 Bucket for RisingWave Object Storage
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "risingwave_data" {
  bucket = "${local.name_prefix}-rw-data-${data.aws_caller_identity.current.account_id}"

  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rw-data"
  })
}

resource "aws_s3_bucket_versioning" "risingwave_data" {
  bucket = aws_s3_bucket.risingwave_data.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "risingwave_data" {
  bucket = aws_s3_bucket.risingwave_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "risingwave_data" {
  bucket = aws_s3_bucket.risingwave_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# S3 Bucket for Loki Log Storage (hosted telemetry)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "loki_logs" {
  bucket = "${local.name_prefix}-loki-logs-${data.aws_caller_identity.current.account_id}"

  # Allow deletion of non-empty bucket for testing
  force_destroy = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-loki-logs"
  })
}

resource "aws_s3_bucket_versioning" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# S3 Bucket + DynamoDB Table for Terraform Remote State
# Used by CloudAgent to manage k8s_resources via Terraform
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"

  force_destroy = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-tfstate"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${local.name_prefix}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-tflock"
  })
}
