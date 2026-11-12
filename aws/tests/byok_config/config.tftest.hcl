# Override only the remote-state read. Execute the production YAML expressions
# through symlinks so this test cannot drift into a second copy of the renderer.
override_data {
  target = data.terraform_remote_state.base_env
  values = {
    outputs = {
      aws_account_id                       = "123456789012"
      cloudagent_role_arn                  = "fixture-cloudagent-role-arn"
      cloudagent_target_group_arn          = "fixture-cloudagent-target-group-arn"
      cloudagent_vpc_endpoint_service_name = "fixture-cloudagent-vpc-endpoint-service-name"
      cloudagent_zpage_target_group_arn    = "fixture-cloudagent-zpage-target-group-arn"
      ebs_encryption_key_arn               = "fixture-ebs-encryption-key-arn"
      eks_cluster_name                     = "fixture-eks-cluster-name"
      heap_bucket_arn                      = "arn:aws:s3:::test-heap"
      heap_bucket_name                     = "test-heap"
      loki_role_arn                        = "fixture-loki-role-arn"
      loki_s3_bucket_arn                   = "arn:aws:s3:::test-logs"
      private_subnet_cidrs                 = ["10.0.1.0/24"]
      region                               = "us-east-1"
      rwproxy_internal_target_group_arn    = "fixture-rwproxy-internal-target-group-arn"
      rwproxy_metrics_target_group_arn     = "fixture-rwproxy-metrics-target-group-arn"
      rwproxy_vpc_endpoint_service_name    = "fixture-rwproxy-vpc-endpoint-service-name"
      rwproxy_webhook_target_group_arn     = "fixture-rwproxy-webhook-target-group-arn"
      s3_bucket_arn                        = "arn:aws:s3:::test-data"
      tags                                 = {}
      terraform_lock_dynamodb_table_name   = "fixture-terraform-lock-dynamodb-table-name"
      terraform_state_s3_bucket_name       = "fixture-terraform-state-s3-bucket-name"
    }
  }
}
variables {
  region           = "us-east-1"
  eks_cluster_name = "test-eks"
}
run "byok_config_yaml" {
  command = plan
  assert {
    condition = yamldecode(output.byok_config_yaml) == {
      cloud_provider = "aws"
      region         = "us-east-1"
      aws = {
        account_id       = "123456789012"
        eks_cluster_name = "fixture-eks-cluster-name"
        s3_buckets = {
          data_store_arn = "arn:aws:s3:::test-data"
          log_store_arn  = "arn:aws:s3:::test-logs"
          heap_store_arn = "arn:aws:s3:::test-heap"
        }
        ebs_encryption_key_arn = "fixture-ebs-encryption-key-arn"
        iam_roles = {
          cloudagent_role_arn = "fixture-cloudagent-role-arn"
          loki_role_arn       = "fixture-loki-role-arn"
        }
        network_load_balancers = {
          cloudagent_target_group_arn          = "fixture-cloudagent-target-group-arn"
          cloudagent_zpage_target_group_arn    = "fixture-cloudagent-zpage-target-group-arn"
          rwproxy_target_group_arn             = "fixture-rwproxy-internal-target-group-arn"
          rwproxy_webhook_target_group_arn     = "fixture-rwproxy-webhook-target-group-arn"
          rwproxy_metrics_target_group_arn     = "fixture-rwproxy-metrics-target-group-arn"
          cloudagent_subnet_cidrs              = ["10.0.1.0/24"]
          rwproxy_subnet_cidrs                 = ["10.0.1.0/24"]
          cloudagent_vpc_endpoint_service_name = "fixture-cloudagent-vpc-endpoint-service-name"
          rwproxy_vpc_endpoint_service_name    = "fixture-rwproxy-vpc-endpoint-service-name"
        }
        terraform_state = {
          s3_bucket_name      = "fixture-terraform-state-s3-bucket-name"
          dynamodb_table_name = "fixture-terraform-lock-dynamodb-table-name"
        }
      }
    }
    error_message = "Generated creation YAML must match the complete public BYOK configuration, including all three buckets."
  }
}
