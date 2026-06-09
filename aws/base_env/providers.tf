terraform {
  # Local backend - no remote state needed for testing
  backend "local" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.7"
    }
  }
}

locals {
  name_prefix = "byok-${var.user_prefix}"

  default_tags = {
    Project     = "RisingWave-BYOK-Test"
    Environment = "test"
    Owner       = var.user_prefix
  }
  tags = merge(local.default_tags, var.tags)
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
