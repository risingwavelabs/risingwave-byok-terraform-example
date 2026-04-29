# aws/tenant_resources

Provisions per-cluster AWS resources that a RisingWave cluster running in a BYOK environment requires:

| Resource | Purpose |
| --- | --- |
| RDS PostgreSQL instance | Metadata store for the RisingWave cluster |
| IAM role with IRSA trust policy + S3 access | Workload identity for the RisingWave cluster pods to reach the S3 data store |

This module emits the `byok_tenant_config.yaml` you feed into `rwc cluster byok-config` to complete two-phase tenant provisioning.

> **Prerequisite**: [`aws/base_env`](../base_env/) must be applied first. The module reads VPC, subnets, OIDC provider, and S3 ARN from base_env's `terraform.tfstate`.

> **Run once per RisingWave cluster.** If you create multiple RisingWave clusters in the same BYOK environment, run this module once per cluster (use a separate Terraform workspace or copy the directory).

## Workflow

This is **Phase 2** of the two-phase BYOK cluster creation flow. Before applying this module:

1. Create the cluster shell:
   ```bash
   rwc cluster create --tier BYOK --env <env-name> --name <cluster-name> ...
   ```
   The cluster starts in `AwaitingConfig` status.

2. Retrieve the namespace and service account allocated by RisingWave:
   ```bash
   rwc cluster describe --uuid <uuid>
   # Look for: Resource Namespace: rwc-xxxxxxxxxxxx-<cluster-name>
   #           Service Account:    <cluster-name>
   ```

## Inputs

| Variable | Description |
| --- | --- |
| `tenant_namespace` | `Resource Namespace` from `rwc cluster describe` |
| `tenant_service_account` | `Service Account` from `rwc cluster describe` |
| `rds_password` | Master password for the RDS metastore (sensitive) |
| `rds_instance_class` | Default `db.t4g.micro`; size up for production |
| `rds_db_name` | Default `risingwave` |
| `rds_username` | Default `risingwave` |

## Apply

```bash
terraform init
terraform apply \
  -var "tenant_namespace=rwc-xxxxxxxxxxxx-my-cluster" \
  -var "tenant_service_account=my-cluster" \
  -var "rds_password=<choose-a-strong-password>"
```

## Generated config: `byok_tenant_config.yaml`

After apply, write the generated tenant config to a file:

```bash
terraform output -raw byok_tenant_config_yaml > ../byok_tenant_config.yaml
```

The password is **not** included in the YAML (it would be checked in by accident). Pass it via the `RWC_BYOK_METASTORE_PASSWORD` environment variable when invoking the CLI:

```bash
export RWC_BYOK_METASTORE_PASSWORD='<the-rds-password-you-set>'
rwc cluster byok-config --uuid <uuid> --config ../byok_tenant_config.yaml
```

This transitions the cluster from `AwaitingConfig` to `Creating` and triggers provisioning.

## Destroy

> Destroy this module only after `rwc cluster delete --uuid <uuid>` completes — RisingWave still needs the metastore and IAM role until then.

```bash
terraform destroy \
  -var "tenant_namespace=unused" \
  -var "tenant_service_account=unused" \
  -var "rds_password=unused"
```
