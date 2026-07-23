# aws/base_env

Provisions the AWS infrastructure that RisingWave Cloud BYOK requires you to bring.

## What it creates

| Resource | Purpose |
| --- | --- |
| VPC + public/private subnets across 3 AZs, NAT gateway, S3 endpoint | Network foundation for the BYOK environment |
| EKS cluster + Karpenter controller managed node group | Kubernetes cluster that hosts BYOK workloads |
| EBS CSI driver, VPC CNI add-ons | Required EKS add-ons |
| 2 S3 buckets | Data store (RisingWave state) and log store (Loki) |
| KMS key | EBS volume encryption |
| IAM roles (with IRSA) | CloudAgent, Loki, AWS Load Balancer Controller |
| 2 NLBs + 5 target groups | CloudAgent (40001 + zpage 40090) and RWProxy (4566 + webhook 4580 + metrics 9099) |
| 2 VPC Endpoint Services | PrivateLink connectivity from the RisingWave control plane |

## Inputs

Required:

| Variable | Description |
| --- | --- |
| `user_prefix` | Unique 1–12 char lowercase prefix for resource names (e.g. `acme`, `team1`) |

Common optional overrides — see [variables.tf](variables.tf) for the full list:

| Variable | Default |
| --- | --- |
| `region` | `us-east-1` |
| `vpc_cidr` | `10.0.0.0/16` |
| `kubernetes_version` | `1.34` |
| `control_plane_aws_account_id` | `600598779918` (RisingWave Cloud production) |


## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set user_prefix at minimum

terraform init
terraform apply
```

After apply, configure `kubectl`:

```bash
aws eks update-kubeconfig \
  --name $(terraform output -raw eks_cluster_name) \
  --region $(terraform output -raw region)
```

## Next step

Apply the [`k8s_addons`](../k8s_addons/) module to install cert-manager, AWS Load Balancer Controller, and Karpenter NodePools.

## Destroy

> **Order matters**: destroy `tenant_resources` (if applied) and `k8s_addons` before destroying `base_env`.

```bash
terraform destroy
```

The S3 buckets are configured with `force_destroy = true` for clean teardown.
