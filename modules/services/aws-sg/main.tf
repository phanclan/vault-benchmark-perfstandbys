#-------------------------------------------------------------------------------
# SECURITY GROUPS
#-------------------------------------------------------------------------------

// Security group for Vault
resource "aws_security_group" "this" {
  name        = "${var.prefix}-${var.vault_name_prefix}-sg"
  description = "Vault servers"
  vpc_id      = var.vpc_id
  tags = var.tags
}

resource "aws_security_group_rule" "vault_8200_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  # cidr_blocks = ["${chomp(data.http.current_ip.body)}/32"]
  cidr_blocks = [var.my_ip]
}

# Peter - allow traffic for consul and vault from CIDR
resource "aws_security_group_rule" "consul_vault_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 8000
  to_port           = 9200
  protocol          = "tcp"
  cidr_blocks = flatten([var.my_ip, var.ingress_cidr_blocks])
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
  cidr_blocks = flatten([var.my_ip, var.ingress_cidr_blocks])
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

resource "aws_security_group_rule" "ssh_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks = [var.my_ip]
}

resource "aws_security_group_rule" "http_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "postgres_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks = [var.my_ip]
}

# Peter - allow traffic for fabio and Prometheus from CIDR
resource "aws_security_group_rule" "prometheus_vault_in" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 9998
  to_port           = 9999
  protocol          = "tcp"
  cidr_blocks = flatten([var.my_ip, var.ingress_cidr_blocks])
}

resource "aws_security_group_rule" "hashi_any_out" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
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