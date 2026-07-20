# ------------------------------------------------------------------------------
# VPC for BYOK Test Environment
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # Use provided AZs, or default to first 3 available in the region.
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  # Subnet CIDR calculations.
  #
  # Private subnets hold EKS worker nodes (and pod IPs via the AWS VPC CNI),
  # so they need to be large. Public subnets only host NAT gateway ENIs and
  # public load-balancer ENIs, so they can be much smaller.
  #
  # For a /16 VPC: three /18 (~16k IPs) for private, three /22 (~1k IPs) for
  # public. Supports up to 3 AZs (enforced by var.availability_zones).
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 2, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(cidrsubnet(var.vpc_cidr, 2, 3), 4, i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway      = true
  single_nat_gateway      = true # Cost optimization for test env
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = false

  # Tags required for EKS and AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                         = 1
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = 1
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
    "karpenter.sh/discovery"                         = "${local.name_prefix}-eks"
  }

  tags = local.tags
}

# S3 Gateway Endpoint (cost optimization - S3 traffic doesn't go through NAT)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}
