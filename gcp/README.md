# GCP BYOK Terraform Example

GCP GKE support for BYOK is **planned** but not yet implemented. This directory is a placeholder.

When available, this directory will mirror the structure of [`aws/`](../aws/):

- `base_env/` — VPC, GKE cluster, GCS buckets, IAM service accounts, internal load balancers
- `k8s_addons/` — cert-manager and any other GCP-specific add-ons
- `tenant_resources/` — Cloud SQL metastore + per-cluster service account
