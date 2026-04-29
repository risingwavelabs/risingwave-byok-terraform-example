# AWS BYOK Terraform Example

Terraform code to bootstrap a RisingWave BYOK environment on **AWS EKS**.

## Modules

| Module | Description | When to apply |
| --- | --- | --- |
| [`base_env/`](base_env/) | VPC, EKS, S3 buckets, KMS, IAM roles, NLBs, VPC endpoint services | Once per BYOK environment |
| [`k8s_addons/`](k8s_addons/) | cert-manager, AWS LB Controller, Karpenter NodePools | Once per BYOK environment, after `base_env` |
| [`tenant_resources/`](tenant_resources/) | RDS metastore + per-cluster IAM role | Once per RisingWave cluster |

## Quickstart

```bash
# 1. Provision AWS infrastructure
cd base_env
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set user_prefix
terraform init
terraform apply

# 2. Install Kubernetes add-ons
cd ../k8s_addons
REGION=$(terraform -chdir=../base_env output -raw region)
EKS_CLUSTER=$(terraform -chdir=../base_env output -raw eks_cluster_name)
terraform init
terraform apply -var "region=${REGION}" -var "eks_cluster_name=${EKS_CLUSTER}"

# 3. Generate the BYOK config and register the environment with RisingWave Cloud
terraform output -raw byok_config_yaml > ../byok_config.yaml
rwc byok create --name <env-name> --config ../byok_config.yaml
rwc byok apply --name <env-name>

# 4. Create a RisingWave cluster (Phase 1)
rwc cluster create --tier BYOK --env <env-name> --name <cluster-name> ...
rwc cluster describe --uuid <uuid>
# Note the Resource Namespace and Service Account values

# 5. Provision the cluster's RDS metastore + IAM role
cd ../tenant_resources
terraform init
terraform apply \
  -var "tenant_namespace=<resource-namespace>" \
  -var "tenant_service_account=<service-account>" \
  -var "rds_password=<choose-a-strong-password>"

# 6. Generate the tenant config and complete cluster provisioning (Phase 2)
terraform output -raw byok_tenant_config_yaml > ../byok_tenant_config.yaml
export RWC_BYOK_METASTORE_PASSWORD='<the-rds-password-you-set>'
rwc cluster byok-config --uuid <uuid> --config ../byok_tenant_config.yaml
```

See each module's README for full details.

## Teardown order

To avoid dangling references, destroy in reverse order:

1. `rwc cluster delete --uuid <uuid>` for each RW cluster
2. `terraform destroy` in `tenant_resources/`
3. `rwc byok terminate --name <env-name>` then `rwc byok delete --name <env-name>`
4. `terraform destroy` in `k8s_addons/`
5. `terraform destroy` in `base_env/`
