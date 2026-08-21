terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.logs_bucket_name
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

# Single HTTP listener on 80, redirecting every host/port to the primary
# (backend) HTTPS listener - admin traffic reaches its own HTTPS port directly.
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ---------------------------------------------------------------------------
# Blue/green target group pair, per service. CodeDeploy owns which of the
# pair the listener's default action forwards to at any moment - Terraform
# only creates both and wires the listener to "blue" as the initial state.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "blue" {
  for_each = var.services

  name        = "${var.name_prefix}-${each.key}-tg-blue"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate tasks register by IP

  health_check {
    path                = each.value.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200-299"
  }

  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-tg-blue" })
}

resource "aws_lb_target_group" "green" {
  for_each = var.services

  name        = "${var.name_prefix}-${each.key}-tg-green"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = each.value.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200-299"
  }

  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-tg-green" })
}

resource "aws_lb_listener" "https" {
  for_each = var.services

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.listener_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue[each.key].arn
  }

  # CodeDeploy's ECS blue/green hook rewrites this listener's default_action
  # during every deployment; Terraform must not fight that after day 1.
  lifecycle {
    ignore_changes = [default_action]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-https" })
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.web_acl_arn
}
