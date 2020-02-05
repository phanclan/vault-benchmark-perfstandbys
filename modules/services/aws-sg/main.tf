#-------------------------------------------------------------------------------
# SECURITY GROUPS
#-------------------------------------------------------------------------------

// Security group for Vault
resource "aws_security_group" "this" {
  name        = "${var.vault_name_prefix}-sg"
  description = "Vault servers"
  vpc_id      = var.vpc_id
  tags = var.tags
}

resource "aws_security_group_rule" "vault_ssh" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = [var.workstation-external-cidr]
}

resource "aws_security_group_rule" "vault_8200_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  # cidr_blocks = ["${chomp(data.http.current_ip.body)}/32"]
  cidr_blocks = [var.workstation-external-cidr]
}

# Peter - allow traffic for consul and vault from CIDR
resource "aws_security_group_rule" "consul_vault_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 9200
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = flatten([var.workstation-external-cidr, var.ingress_cidr_blocks])
}

# Peter - allow traffic for consul and vault from SG
resource "aws_security_group_rule" "consul_vault_in_sg" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 9200
  protocol          = "tcp"
  source_security_group_id = aws_security_group.this.id
}

# Peter - allow traffic for Nomad from CIDR
resource "aws_security_group_rule" "nomad_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 4646
  to_port           = 4648
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks = flatten([var.workstation-external-cidr, var.ingress_cidr_blocks])
}

# Peter - allow traffic for Nomad from SG
resource "aws_security_group_rule" "nomad_in_sg" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 4646
  to_port           = 4648
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  source_security_group_id = aws_security_group.this.id
}

# Peter - allow traffic for fabio and Prometheus from CIDR
resource "aws_security_group_rule" "prometheus_vault_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 9998
  to_port           = 9999
  protocol          = "tcp"
  cidr_blocks = flatten([var.workstation-external-cidr, var.ingress_cidr_blocks])
}

# locals {
#   my_ip = "${chomp(data.http.current_ip.body)}/32"
# }

resource "aws_security_group_rule" "vault_postgres_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks = [var.workstation-external-cidr]
}

resource "aws_security_group_rule" "vault_any_egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# For testing
resource "aws_security_group_rule" "vault_external_egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "vault_internal_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}

# Might not need for NLB
# resource "aws_security_group_rule" "vault_elb_access" {
#   security_group_id        = aws_security_group.this.id
#   type                     = "ingress"
#   from_port                = 8200
#   to_port                  = 8200
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.vault_elb.id
# }

# Might not need for NLB
# # Allow SSH from ELB
# resource "aws_security_group_rule" "ssh_elb_access" {
#   security_group_id        = aws_security_group.this.id
#   type                     = "ingress"
#   from_port                = 22
#   to_port                  = 22
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.vault_elb.id
# }

# Might not need for NLB
# resource "aws_security_group_rule" "consul_elb_access" {
#   security_group_id        = aws_security_group.this.id
#   type                     = "ingress"
#   from_port                = 8500
#   to_port                  = 8500
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.vault_elb.id
# }

resource "aws_security_group_rule" "vault_cluster" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8201
  to_port                  = 8201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}

// This rule allows Consul RPC.
resource "aws_security_group_rule" "consul_rpc" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}

// This rule allows Consul Serf TCP.
resource "aws_security_group_rule" "vault_consul_serf_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}

// This rule allows Consul Serf UDP.
resource "aws_security_group_rule" "vault_consul_serf_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8302
  protocol                 = "udp"
  source_security_group_id = aws_security_group.this.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}

// This rule allows Consul DNS.
resource "aws_security_group_rule" "consul_dns_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "udp"
  source_security_group_id = aws_security_group.this.id
}
