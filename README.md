# risingwave-byok-terraform-example

Reference Terraform code to bootstrap a [RisingWave BYOK (Bring Your Own Kubernetes)](https://docs.risingwave.com/cloud/project-byok) environment.

This repo provisions all the AWS infrastructure that RisingWave Cloud BYOK requires you to bring: VPC, EKS cluster with Karpenter node pools, S3 buckets, KMS keys, NLBs with PrivateLink endpoint services, IAM roles, RDS metastore, and the Kubernetes add-ons (cert-manager, AWS Load Balancer Controller).

> **Cloud provider support**: AWS only at the moment. GCP support is planned and will live under `gcp/`.

> **Use as a starting point.** This is a reference implementation — fork it, adapt it to your network/security policies, and pin it to a specific tag.

## Repository layout

```
risingwave-byok-terraform-example/
├── aws/
│   ├── base_env/            # VPC, EKS, S3, KMS, NLBs, IAM roles
│   ├── k8s_addons/          # cert-manager, AWS LB Controller, Karpenter NodePools
│   └── tenant_resources/    # Per-cluster RDS metastore + IAM role (run once per RW cluster)
└── gcp/                     # Coming with GCP GKE support
```

## End-to-end workflow

The workflow has two phases. The **environment** is provisioned once; **per-cluster resources** are provisioned every time you create a new RisingWave cluster in the BYOK environment.

### Phase 1: Provision the BYOK environment (once)

1. **Provision AWS infrastructure** — see [aws/base_env/README.md](aws/base_env/README.md)
2. **Install Kubernetes add-ons** — see [aws/k8s_addons/README.md](aws/k8s_addons/README.md)
3. **Register and apply the BYOK environment with RisingWave Cloud**:

   ```bash
   rwc byok create --name <env-name> --config aws/byok_config.yaml
   rwc byok apply --name <env-name>
   ```

   `aws/byok_config.yaml` is generated for you by the `k8s_addons` module — see its README.

### Phase 2: Provision per-cluster resources (each new cluster)

1. **Create the RisingWave cluster (Phase 1 of two-phase provisioning)**:

   ```bash
   rwc cluster create --tier BYOK --env <env-name> --name <cluster-name> ...
   rwc cluster describe --uuid <uuid>
   # Note the Resource Namespace and Service Account
   ```

2. **Provision the cluster's RDS metastore and IAM role** — see [aws/tenant_resources/README.md](aws/tenant_resources/README.md)
3. **Configure the cluster (Phase 2 of two-phase provisioning)**:

   ```bash
   export RWC_BYOK_METASTORE_PASSWORD='<rds-password>'
   rwc cluster byok-config --uuid <uuid> --config aws/byok_tenant_config.yaml
   ```

   `aws/byok_tenant_config.yaml` is generated for you by the `tenant_resources` module — see its README.

## Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/) configured with credentials that can manage EKS, EC2, IAM, S3, KMS, RDS, ELBv2
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [`rwc` CLI](https://docs.risingwave.com/cloud/install-cli)

## Versioning

Tags on this repo align with RisingWave Cloud BYOK module releases. When pinning, use a tag that matches the BYOK control plane version you intend to deploy (e.g. `v2026.16.x`).

## License

Apache 2.0 — see [LICENSE](LICENSE).
