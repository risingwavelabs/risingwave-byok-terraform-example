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
resource "aws_lb" "cloudagent" {
  name               = "${local.name_prefix}-ca"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  enable_cross_zone_load_balancing = true

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

  tags = merge(local.tags, {
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

  tags = merge(local.tags, {
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

  enable_cross_zone_load_balancing = true

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

  tags = merge(local.tags, {
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

  tags = merge(local.tags, {
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

  tags = merge(local.tags, {
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
