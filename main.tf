provider "aws" {
  region = var.region
}

#-------------------------------------------------------------------------------
# DATA SOURCE FOR USER IP. NEED TO REDO IF GOING TO TFE
#-------------------------------------------------------------------------------

data "http" "current_ip" {
  url = "http://ipv4.icanhazip.com/"
}
locals {
  workstation-external-cidr = "${chomp(data.http.current_ip.body)}/32"
}
#-------------------------------------------------------------------------------
# DATA SOURCE FOR USER DATA TEMPLATE FILE
#-------------------------------------------------------------------------------
data "template_file" "install_vault" {
  template = "${join("\n", list(
    file("${path.module}/templates/shared/base.sh"),
    file("${path.module}/templates/servers/install_vault_server.sh.tpl"),
  ))}"

  vars = {
    install_unzip       = var.unzip_command
    vault_download_url  = var.vault_download_url
    consul_download_url = var.consul_download_url
    vault_config        = var.vault_config
    consul_config       = var.consul_client_config
    tag_value           = var.auto_join_tag
    VAULT_LICENSE       = var.vault_license
    vault_license       = var.vault_license
    vault_license2      = "test"
    VAULT_ADDR          = "http://127.0.0.1:8200"
  }
}

data "template_file" "install_consul" {
  template = "${join("\n", list(
    file("${path.module}/templates/shared/base.sh"),
    file("${path.module}/templates/servers/install_consul_server.sh.tpl"),
    file("${path.module}/templates/servers/nomad.sh"),
  ))}"
# data "template_file" "install_consul" {
#   template = "${join("\n", list(
#     file("${path.module}/templates/servers/install_consul_server.sh.tpl"),
#   ))}"

  vars = {
    install_unzip       = var.unzip_command
    consul_download_url = var.consul_download_url
    consul_config       = var.consul_server_config
    tag_value           = var.auto_join_tag
    consul_nodes        = var.consul_nodes
  }
}

# Gzip cloud-init config
data "template_cloudinit_config" "vault" {

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.install_vault.rendered
  }
}


#-------------------------------------------------------------------------------
# IAM INSTANCE PROFILE
#-------------------------------------------------------------------------------


resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.vault_name_prefix
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.vault_name_prefix
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${var.vault_name_prefix}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }
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
    Name        = "${var.prefix}-${var.env}-usw2-1"
    TTL         = "72"
  }
  ttl         = "72"
}