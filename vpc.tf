module "vpc_usw2-1" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "${var.prefix}-${var.env}-uw1-vpc-${random_id.env_name.hex}"
  cidr                 = var.cidr
  azs                  = var.azs
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true
  # enable_nat_gateway   = true
  # single_nat_gateway = true
  tags                     = local.common_tags
  igw_tags                 = { Name = "${var.prefix}-${var.env}-usw2-1-IGW" }
  nat_gateway_tags         = { Name = "${var.prefix}-${var.env}-usw2-1-NGW" }
  public_route_table_tags  = { Name = "${var.prefix}-${var.env}-usw2-1-RT-public" }
  public_subnet_tags       = { Name = "${var.prefix}-${var.env}-usw2-1-public" }
  private_route_table_tags = { Name = "${var.prefix}-${var.env}-usw2-1-RT-private" }
  private_subnet_tags      = { Name = "${var.prefix}-${var.env}-usw2-1-private" }
}

#-------------------------------------------------------------------------------
# SECURITY GROUPS
#-------------------------------------------------------------------------------

// Security group for Vault
resource "aws_security_group" "vault" {
  name        = "${var.vault_name_prefix}-sg"
  description = "Vault servers"
  vpc_id      = module.vpc_usw2-1.vpc_id
}


resource "aws_security_group_rule" "vault_ssh" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = ["${chomp(data.http.current_ip.body)}/32"]
}

resource "aws_security_group_rule" "vault_8200_in" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = ["${chomp(data.http.current_ip.body)}/32"]
}

# Peter - allow traffic for consul and vault from CIDR
resource "aws_security_group_rule" "consul_vault_in" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 9200
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = flatten([local.my_ip, var.ingress_cidr_blocks])
}

# Peter - allow traffic for Nomad from CIDR
resource "aws_security_group_rule" "nomad_in" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 4646
  to_port           = 4646
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = flatten([local.my_ip, var.ingress_cidr_blocks])
}

# Peter - allow traffic for consul and vault from SG
resource "aws_security_group_rule" "consul_vault_in_sg" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 9200
  protocol          = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

locals {
  my_ip = "${chomp(data.http.current_ip.body)}/32"
}

resource "aws_security_group_rule" "vault_postgres_in" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["${chomp(data.http.current_ip.body)}/32"]
}

resource "aws_security_group_rule" "vault_any_egress" {
  security_group_id = aws_security_group.vault.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# For testing
resource "aws_security_group_rule" "vault_external_egress" {
  security_group_id = aws_security_group.vault.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "vault_internal_egress" {
  security_group_id        = aws_security_group.vault.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group_rule" "vault_elb_access" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault_elb.id
}

resource "aws_security_group_rule" "consul_elb_access" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault_elb.id
}

resource "aws_security_group_rule" "vault_cluster" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8201
  to_port                  = 8201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul RPC.
resource "aws_security_group_rule" "consul_rpc" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul Serf TCP.
resource "aws_security_group_rule" "vault_consul_serf_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul Serf UDP.
resource "aws_security_group_rule" "vault_consul_serf_udp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "udp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_tcp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_udp" {
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "udp"
  source_security_group_id = aws_security_group.vault.id
}

# --------------------------------------------------------
# CREATE A NEW ELB - VAULT
# --------------------------------------------------------
// Launch the ELB that is serving Vault. This has proper health checks
// to only serve healthy, unsealed Vaults.
resource "aws_elb" "vault" {
  name                        = "${var.vault_name_prefix}-elb"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = var.elb_internal
  subnets                     = module.vpc_usw2-1.public_subnets
  security_groups             = [aws_security_group.vault_elb.id]

  listener {
    instance_port     = 8200
    instance_protocol = "tcp"
    lb_port           = 8200
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2 # was 3
    timeout             = 3 # was 5
    target              = var.vault_elb_health_check
    interval            = 10 # was 15
  }
}

// Launch the ELB that is serving Consul. This has proper health checks
// to only serve healthy, unsealed Consuls.
resource "aws_elb" "consul" {
  name                        = "${var.consul_name_prefix}-elb"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = var.elb_internal
  subnets                     = module.vpc_usw2-1.public_subnets
  security_groups             = ["${aws_security_group.vault_elb.id}"]

  listener {
    instance_port     = 8500
    instance_protocol = "tcp"
    lb_port           = 8500
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    target              = var.consul_elb_health_check
    interval            = 15
  }
}

resource "aws_security_group" "vault_elb" {
  name        = "${var.vault_name_prefix}-elb"
  description = "Vault ELB"
  vpc_id      = module.vpc_usw2-1.vpc_id
}

resource "aws_security_group_rule" "vault_elb_http" {
  security_group_id = aws_security_group.vault_elb.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "consul_elb_http" {
  security_group_id = aws_security_group.vault_elb.id
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "vault_elb_egress_to_vault" {
  security_group_id        = aws_security_group.vault_elb.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

resource "aws_security_group_rule" "vault_elb_egress_to_consul" {
  security_group_id        = aws_security_group.vault_elb.id
  type                     = "egress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}