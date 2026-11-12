mock_provider "aws" {}

variables {
  bucket_name       = "byok-test-heap-123456789012"
  role_name         = "byok-test-s3-csi"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/TEST"
}

run "private_bucket_and_driver_identity" {
  command = plan

  assert {
    condition     = aws_s3_bucket.heap.bucket == var.bucket_name && !aws_s3_bucket.heap.force_destroy
    error_message = "Heap dumps must use the dedicated bucket and require explicit cleanup before destruction."
  }
  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.heap.block_public_acls,
      aws_s3_bucket_public_access_block.heap.block_public_policy,
      aws_s3_bucket_public_access_block.heap.ignore_public_acls,
      aws_s3_bucket_public_access_block.heap.restrict_public_buckets,
    ]) && one(aws_s3_bucket_server_side_encryption_configuration.heap.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "Heap dumps must be encrypted and all public access blocked."
  }
  assert {
    condition = jsondecode(aws_iam_role.driver.assume_role_policy) == jsondecode(jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = { Federated = var.oidc_provider_arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = { StringEquals = {
          "oidc.eks.us-east-1.amazonaws.com/id/TEST:aud" = "sts.amazonaws.com"
          "oidc.eks.us-east-1.amazonaws.com/id/TEST:sub" = "system:serviceaccount:kube-system:s3-csi-driver-sa"
        } }
      }]
    }))
    error_message = "Only the CSI driver service account from this cluster may assume the heap role."
  }
  assert {
    condition = jsondecode(aws_iam_role_policy.heap.policy) == jsondecode(jsonencode({
      Version = "2012-10-17"
      Statement = [
        { Effect = "Allow", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::byok-test-heap-123456789012" },
        { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"], Resource = "arn:aws:s3:::byok-test-heap-123456789012/heap/*" },
      ]
    }))
    error_message = "Driver access must be limited to listing this bucket and reading/writing heap objects, without delete access."
  }
  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.heap.rule).expiration[0].days == 7 && one(aws_s3_bucket_lifecycle_configuration.heap.rule).abort_incomplete_multipart_upload[0].days_after_initiation == 1
    error_message = "Default retention must expire dumps after 7 days and incomplete uploads after 1 day."
  }
}

run "custom_retention" {
  command = plan
  variables { retention_days = 30 }
  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.heap.rule).expiration[0].days == 30
    error_message = "Customers must be able to configure heap retention."
  }
}

run "reject_zero_retention" {
  command = plan
  variables { retention_days = 0 }
  expect_failures = [var.retention_days]
}

run "reject_fractional_retention" {
  command = plan
  variables { retention_days = 1.5 }
  expect_failures = [var.retention_days]
}
