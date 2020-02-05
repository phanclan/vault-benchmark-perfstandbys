# --------------------------------------------------------
# CREATE A NEW NLB - VAULT
# --------------------------------------------------------

// If EIP is needed
# resource "aws_eip" "eip_nlb" {
#   tags    = {
#     Name  = "test-network-lb-eip"
#     Env   = "test"
#   }
# }

resource "aws_lb" "load_balancer" {
  name               = "vault-network-lb"
  load_balancer_type = "network"
  subnets            = var.public_subnets
  // If EIP is needed
  # subnet_mapping {
  #   subnet_id     = lookup(var.nlb_config,"subnet")
  #   allocation_id = aws_eip.eip_nlb.id
  # }
  tags = {
    Environment = lookup(var.nlb_config, "environment")
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  for_each          = var.forwarding_config
  port              = each.key
  protocol          = each.value
  default_action {
    target_group_arn = "${aws_lb_target_group.tg[each.key].arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "tg" {
  for_each             = var.forwarding_config
  name                 = "${lookup(var.nlb_config, "environment")}-tg-${lookup(var.tg_config, "name")}-${each.key}"
  port                 = each.key
  protocol             = each.value
  # vpc_id               = lookup(var.tg_config, "tg_vpc_id")
  vpc_id               = var.vpc_id
  target_type          = lookup(var.tg_config, "target_type")
  deregistration_delay = 90
  health_check {
    interval            = 60
    port                = each.value != "TCP_UDP" ? each.key : 80
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = {
    Environment = "test"
  }
}

resource "aws_lb_target_group_attachment" "tga1" {
  for_each         = var.forwarding_config
  target_group_arn = "${aws_lb_target_group.tg[each.key].arn}"
  port             = each.key
  target_id        = lookup(var.tg_config, "target_id1")
}

# Move the following to variables.tf
variable "nlb_config" {
  type = "map"
}
variable "tg_config" {
  type = "map"
}
variable "forwarding_config" {
}
