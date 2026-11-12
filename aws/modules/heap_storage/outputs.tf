output "bucket_name" {
  description = "Bucket name to provide to RisingWave for heap-storage configuration."
  value       = aws_s3_bucket.heap.bucket
}

output "driver_role_arn" {
  description = "Driver-level IRSA role for the Mountpoint S3 CSI add-on."
  value       = aws_iam_role.driver.arn
  depends_on  = [aws_iam_role_policy.heap]
}

output "bucket_arn" {
  description = "Heap bucket ARN for the BYOK creation configuration."
  value       = aws_s3_bucket.heap.arn
}
