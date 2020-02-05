# data "aws_ami" "bastion" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }
data "aws_ami" "bastion" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "name"
    values = [var.ami]
  }
}

data "http" "current_ip" {
  url = "http://ipv4.icanhazip.com/"
}

resource "aws_instance" "bastion" {
  count                       = var.bastion_nodes
  ami                         = data.aws_ami.bastion.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  private_ip                  = var.private_ip
  ebs_optimized               = false
  # iam_instance_profile        = "${aws_iam_instance_profile.benchmark.id}"

  vpc_security_group_ids = [
    "${aws_security_group.bastion.id}"
  ]

  tags = {
    Name  = "${var.prefix}-bastion"
    env   = var.env
    role  = "bastion"
    owner = var.owner
    ttl   = var.ttl
  }

  user_data = data.template_file.bastion.rendered
}

data "template_file" "bastion" {
  template = "${join("\n", list(
    file("${path.module}/../../../templates/shared/base.sh"),
    file("${path.module}/../../../templates/servers/bastion.sh"),
  ))}"

  vars = {
    env = var.env
  }
}

# SECURITY GROUPS - INSTANCE
#-------------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.prefix}-bastion-sg"
  description = "Bastion Security Group"
  vpc_id      = var.vpc_id
}

# Allow inbound HTTP requests
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_https_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion.id

  from_port   = 443
  to_port     = 443
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

# Allow inbound ssh requests
resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion.id
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}

resource "aws_security_group_rule" "allow_postgres_in" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = local.tcp_protocol
  cidr_blocks       = ["${chomp(data.http.current_ip.body)}/32"]
}

resource "aws_security_group_rule" "allow_internal_in" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.internal_ips
}

# Allow all outbound requests
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.bastion.id
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  cidr_blocks       = local.all_ips
}


# LOCALS
#-------------------------------------------------------------------------------
locals {
  http_port         = 80
  ssh_port          = 22
  vault_client_port = 8200
  any_port          = 0
  any_protocol      = "-1"
  tcp_protocol      = "tcp"
  all_ips           = ["0.0.0.0/0"]
  internal_ips      = ["10.10.0.0/16"]
}


# OUTPUTS
#-------------------------------------------------------------------------------

output "bastion_pub_ip" {
  value = aws_instance.bastion.*.public_ip
}

output "bastion_pub_dns" {
  value = aws_instance.bastion.*.public_dns
}