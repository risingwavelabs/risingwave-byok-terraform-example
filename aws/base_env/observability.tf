# ------------------------------------------------------------------------------
# Observability
#
# With hosted telemetry (hosted_vm + hosted_loki), AMP and CloudWatch are no
# longer needed. VictoriaMetrics and Loki are deployed in-cluster by the
# k8s_resources_byok module. Only the Loki S3 bucket and IAM role (in s3.tf
# and iam.tf) are required as customer-provided prerequisites.
# ------------------------------------------------------------------------------
