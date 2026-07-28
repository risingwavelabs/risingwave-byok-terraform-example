# ------------------------------------------------------------------------------
# Network Load Balancers + Target Groups + VPC Endpoint Services
# For PrivateLink connectivity from RisingWave control plane to BYOK data plane
#
# Creates:
# - CloudAgent NLB (main port + zpage port)
# - RWProxy Internal NLB (postgres port + webhook port + metrics port)
# - VPC Endpoint Services for both
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CloudAgent NLB
# ------------------------------------------------------------------------------
module "eks_auto_mode_load_balancing" {
  source = "../modules/eks_auto_mode_load_balancing"

  enabled      = var.eks_auto_mode
  cluster_name = local.eks_cluster_name
  target_ports = {
    cloudagent       = var.cloudagent_port
    cloudagent_zpage = var.cloudagent_zpage_port
    rwproxy          = var.rwproxy_port
    rwproxy_metrics  = var.rwproxy_metrics_port
    rwproxy_webhook  = var.rwproxy_webhook_port
  }
  client_ports = {
    rwproxy = var.rwproxy_port
  }
  client_cidrs = concat([var.vpc_cidr], var.rwproxy_additional_client_cidrs)
}

resource "aws_security_group" "nlb" {
  count = module.eks_auto_mode_load_balancing.nlb_security_group_required ? 1 : 0

  name        = "${local.name_prefix}-nlb"
  description = "Security group for EKS Auto Mode native TargetGroupBindings"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nlb"
  })
}

resource "aws_vpc_security_group_egress_rule" "nlb" {
  count = module.eks_auto_mode_load_balancing.nlb_security_group_required ? 1 : 0

  security_group_id = aws_security_group.nlb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "rwproxy_client" {
  count = module.eks_auto_mode_load_balancing.nlb_security_group_required ? 1 : 0

  name        = "${local.name_prefix}-rwproxy-client"
  description = "Direct client access to the EKS Auto Mode RWProxy NLB"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rwproxy-client"
  })
}

resource "aws_vpc_security_group_egress_rule" "rwproxy_client" {
  count = module.eks_auto_mode_load_balancing.nlb_security_group_required ? 1 : 0

  security_group_id = aws_security_group.rwproxy_client[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "rwproxy_clients" {
  for_each = module.eks_auto_mode_load_balancing.nlb_client_ingress_rules

  security_group_id = aws_security_group.rwproxy_client[0].id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "Allow direct RWProxy clients from ${each.value.cidr}"
}

resource "aws_vpc_security_group_ingress_rule" "eks_auto_mode_targets" {
  for_each = module.eks_auto_mode_load_balancing.node_security_group_ingress_ports

  security_group_id            = module.eks.cluster_primary_security_group_id
  referenced_security_group_id = aws_security_group.nlb[0].id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  description                  = "Allow EKS Auto Mode NLB traffic to ${each.key} targets"
}

resource "aws_lb" "cloudagent" {
  name               = "${local.name_prefix}-ca"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets
  security_groups    = module.eks_auto_mode_load_balancing.nlb_security_group_required ? [aws_security_group.nlb[0].id] : null

  enable_cross_zone_load_balancing                             = true
  enforce_security_group_inbound_rules_on_private_link_traffic = module.eks_auto_mode_load_balancing.private_link_security_group_enforcement

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudagent-nlb"
  })
}

# CloudAgent main port target group
resource "aws_lb_target_group" "cloudagent" {
  name        = "${local.name_prefix}-ca"
  port        = var.cloudagent_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(local.tags, module.eks_auto_mode_load_balancing.target_group_tags, {
    Name = "${local.name_prefix}-cloudagent-tg"
  })
}

resource "aws_lb_listener" "cloudagent" {
  load_balancer_arn = aws_lb.cloudagent.arn
  port              = var.cloudagent_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudagent.arn
  }
}

# CloudAgent zpage port target group
resource "aws_lb_target_group" "cloudagent_zpage" {
  name        = "${local.name_prefix}-ca-zp"
  port        = var.cloudagent_zpage_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(local.tags, module.eks_auto_mode_load_balancing.target_group_tags, {
    Name = "${local.name_prefix}-cloudagent-zpage-tg"
  })
}

resource "aws_lb_listener" "cloudagent_zpage" {
  load_balancer_arn = aws_lb.cloudagent.arn
  port              = var.cloudagent_zpage_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudagent_zpage.arn
  }
}

# CloudAgent VPC Endpoint Service
resource "aws_vpc_endpoint_service" "cloudagent" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.cloudagent.arn]
  allowed_principals         = ["arn:aws:iam::${var.control_plane_aws_account_id}:root"]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudagent-vpce-svc"
  })
}

# ------------------------------------------------------------------------------
# RWProxy Internal NLB
# ------------------------------------------------------------------------------
resource "aws_lb" "rwproxy_internal" {
  name               = "${local.name_prefix}-rpi"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets
  security_groups = module.eks_auto_mode_load_balancing.nlb_security_group_required ? [
    aws_security_group.nlb[0].id,
    aws_security_group.rwproxy_client[0].id,
  ] : null

  enable_cross_zone_load_balancing                             = true
  enforce_security_group_inbound_rules_on_private_link_traffic = module.eks_auto_mode_load_balancing.private_link_security_group_enforcement

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rwproxy-internal-nlb"
  })
}

# RWProxy postgres port target group
resource "aws_lb_target_group" "rwproxy_internal" {
  name        = "${local.name_prefix}-rpi"
  port        = var.rwproxy_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(local.tags, module.eks_auto_mode_load_balancing.target_group_tags, {
    Name = "${local.name_prefix}-rwproxy-internal-tg"
  })
}

resource "aws_lb_listener" "rwproxy_internal" {
  load_balancer_arn = aws_lb.rwproxy_internal.arn
  port              = var.rwproxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rwproxy_internal.arn
  }
}

# RWProxy webhook port target group
resource "aws_lb_target_group" "rwproxy_webhook" {
  name        = "${local.name_prefix}-rpi-wh"
  port        = var.rwproxy_webhook_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, module.eks_auto_mode_load_balancing.target_group_tags, {
    Name = "${local.name_prefix}-rwproxy-webhook-tg"
  })
}

resource "aws_lb_listener" "rwproxy_webhook" {
  load_balancer_arn = aws_lb.rwproxy_internal.arn
  port              = var.rwproxy_webhook_listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rwproxy_webhook.arn
  }
}

# RWProxy metrics port target group
resource "aws_lb_target_group" "rwproxy_metrics" {
  name        = "${local.name_prefix}-rpi-m"
  port        = var.rwproxy_metrics_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(local.tags, module.eks_auto_mode_load_balancing.target_group_tags, {
    Name = "${local.name_prefix}-rwproxy-metrics-tg"
  })
}

resource "aws_lb_listener" "rwproxy_metrics" {
  load_balancer_arn = aws_lb.rwproxy_internal.arn
  port              = var.rwproxy_metrics_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rwproxy_metrics.arn
  }
}

# RWProxy VPC Endpoint Service
resource "aws_vpc_endpoint_service" "rwproxy" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.rwproxy_internal.arn]
  allowed_principals         = ["arn:aws:iam::${var.control_plane_aws_account_id}:root"]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-rwproxy-vpce-svc"
  })
}
