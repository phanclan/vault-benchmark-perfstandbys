#-------------------------------------------------------------------------------
# DATA SOURCE FOR USER DATA TEMPLATE FILE
#-------------------------------------------------------------------------------

# data "template_file" "install_vault" {
#   template = "${join("\n", list(
#     file("${path.module}/templates/shared/base.sh"),
#     file("${path.module}/templates/servers/install_vault_server.sh.tpl"),
#   ))}"

#   vars = {
#     # install_unzip       = var.unzip_command
#     # vault_download_url  = var.vault_download_url
#     # consul_download_url = var.consul_download_url
#     vault_config        = var.vault_config
#     consul_config       = var.consul_client_config
#     tag_value           = var.auto_join_tag
#     VAULT_LICENSE       = var.vault_license
#     vault_license       = var.vault_license
#     vault_license2      = "test"
#     VAULT_ADDR          = "http://127.0.0.1:8200"
#   }
# }

# # Gzip cloud-init config - VAULT
# data "template_cloudinit_config" "vault" {
#   gzip          = true
#   base64_encode = true
#   part {
#     content_type = "text/x-shellscript"
#     content      = data.template_file.install_vault.rendered
#   }
# }

data "template_file" "mini_consul" {
  template = "${join("\n", list(
    file("${path.module}/../../../templates/shared/base.sh"),
    file("${path.module}/../../../templates/servers/install_consul_server_mini.sh.tpl"),
  ))}"

  vars = {
    env = var.env
    consul_nodes        = 1
    tag_value           = var.auto_join_tag
  }
}

data "template_file" "mini_vault" {
  template = "${join("\n", list(
    file("${path.module}/../../../templates/shared/base.sh"),
    file("${path.module}/../../../templates/servers/install_vault_server_mini.sh.tpl"),
  ))}"

  vars = {
    env = var.env
    VAULT_ADDR = "http://127.0.0.1:8200"
    vault_license       = var.vault_license
    tag_value           = var.auto_join_tag
  }
}

#-------------------------------------------------------------------------------
# AWS EC2 INSTANCE - VAULT
#-------------------------------------------------------------------------------
resource "aws_instance" "vault" {
  count = var.nodes
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(var.public_subnets, count.index)
  iam_instance_profile   = var.iam_instance_profile
  vpc_security_group_ids = [var.security_group_ids]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true
  }
  tags = merge(
    {
      Name  = "${var.prefix}-vault-${count.index}-${var.env}-${var.region}"
    },
    var.tags,
  )

  # user_data = var.vault_user_data
  user_data = data.template_file.mini_vault.rendered
}

#-------------------------------------------------------------------------------
# AWS EC2 INSTANCE - CONSUL
#-------------------------------------------------------------------------------
resource "aws_instance" "consul" {
  count = var.nodes
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(var.public_subnets, count.index)
  # iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids = [var.security_group_ids]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true
  }
  tags = merge(
    {
      Name  = "${var.prefix}-consul-${count.index}-${var.env}-${var.region}",
      ConsulAutoJoin = var.auto_join_tag
    },
    var.tags,
  )

  # user_data = var.consul_user_data
  user_data = data.template_file.mini_consul.rendered
}


resource "random_id" "env_name" {
  byte_length = 4
  prefix      = "${var.env}-"
}

locals {
  name_prefix = "${var.prefix}-${var.env}-${var.region}"
  common_tags = {
    Owner       = var.owner
    Environment = var.env
    Name        = "${var.prefix}-${var.env}-usw2-2"
    TTL         = "72"
  }
  ttl         = "72"
}

#-------------------------------------------------------------------------------
# AWS R53 DNS RECORDS - VAULT
#-------------------------------------------------------------------------------

resource "aws_route53_record" "this1" {
  count = var.nodes
  zone_id = var.zone_id
  name    = "mini-vault-${count.index}-${var.env}"
  type    = "CNAME"
  records = ["${element(aws_instance.vault.*.public_dns, count.index)}"]
  ttl     = "300"
}

resource "aws_route53_record" "this2" {
  count = var.nodes
  zone_id = var.zone_id
  name    = "mini-consul-${count.index}-${var.env}"
  type    = "CNAME"
  records = ["${element(aws_instance.consul.*.public_dns, count.index)}"]
  ttl     = "300"
}