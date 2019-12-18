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
  template = "${file("${path.module}/scripts/install_vault_server.sh.tpl")}"

  vars = {
    install_unzip       = var.unzip_command
    vault_download_url  = var.vault_download_url
    consul_download_url = var.consul_download_url
    vault_config        = var.vault_config
    consul_config       = var.consul_client_config
    tag_value           = var.auto_join_tag
  }
}

data "template_file" "install_consul" {
  template = "${file("${path.module}/scripts/install_consul_server.sh.tpl")}"

  vars = {
    install_unzip       = var.unzip_command
    consul_download_url = var.consul_download_url
    consul_config       = var.consul_server_config
    tag_value           = var.auto_join_tag
    consul_nodes        = var.consul_nodes
  }
}

#-------------------------------------------------------------------------------
# LAUNCH CONFIGURATION AND AUTOSCALING GROUP
#-------------------------------------------------------------------------------
module "example" {
  source = "./modules/services/aws-autoscaling"

  name = "pphan-benchmark-vault"

  # Launch configuration
  #
  # launch_configuration = "my-existing-launch-configuration" # Use the existing launch configuration
  # create_lc = false # disables creation of launch configuration
  lc_name = "pphan-benchmark-vault-lc"

  image_id                     = data.aws_ami.hashistack.id
  instance_type                = var.instance_type_vault
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                     = var.key_name
  security_groups              = [aws_security_group.vault.id]
  associate_public_ip_address  = true
  user_data                    = data.template_file.install_vault.rendered
  enable_monitoring            = false # not common
  spot_price                   = var.spot_price # 0.025
  ebs_optimized                = var.ebs_optimized # not common
  # recreate_asg_when_lc_changes = true

  root_block_device = [
    {
      # volume_type = "io1"
      # iops        = "2500" # only for io1 volume_type
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = true
    },
  ]

  # ebs_block_device = [
  #   {
  #     device_name           = "/dev/xvdz"
  #     volume_type           = "gp2"
  #     volume_size           = "50"
  #     delete_on_termination = true
  #   },
  # ]

  # Auto scaling group
  #-------------------
  asg_name                  = "pphan-benchmark-vault" # CHANGE
  vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
  health_check_type         = "ELB"
  min_size                  = 0
  max_size                  = var.vault_nodes
  desired_capacity          = var.vault_nodes
  health_check_grace_period = 15
  # wait_for_capacity_timeout = 0
  # service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  # Currently, load balancer config is included with ASG module.
  load_balancers            = [aws_elb.vault.id] # only for elb. alb use target_group_arns

  tags = [
    {
      key                 = "Name"
      value               = var.vault_name_prefix
      propagate_at_launch = true
    },
    {
      key                 = "ConsulAutoJoin"
      value               = var.auto_join_tag
      propagate_at_launch = true
    },
    {
      key                 = "owner"
      value               = var.owner
      propagate_at_launch = true
    },
    {
      key                 = "ttl"
      value               = var.ttl
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]

  # tags_as_map = {
  #   extra_tag1 = "extra_value1"
  #   extra_tag2 = "extra_value2"
  # }
}


 
# // We launch Vault into an ASG so that it can properly bring them up for us.
# resource "aws_autoscaling_group" "vault" {
#   name                      = aws_launch_configuration.vault.name
#   launch_configuration      = aws_launch_configuration.vault.name
#   # availability_zones        = var.azs # For EC2-Classic VPC
#   vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
#   min_size                  = 1
#   max_size                  = var.vault_nodes
#   desired_capacity          = var.vault_nodes
#   health_check_grace_period = 15
#   health_check_type         = "ELB"
#   load_balancers            = [aws_elb.vault.id] # only for elb. alb use target_group_arns

#   tags = [
#     {
#       key                 = "Name"
#       value               = var.vault_name_prefix
#       propagate_at_launch = true
#     },
#     {
#       key                 = "ConsulAutoJoin"
#       value               = var.auto_join_tag
#       propagate_at_launch = true
#     },
#     {
#       key                 = "owner"
#       value               = var.owner
#       propagate_at_launch = true
#     },
#     {
#       key                 = "ttl"
#       value               = var.ttl
#       propagate_at_launch = true
#     }
#   ]

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_launch_configuration" "vault" {
#   name_prefix                 = var.vault_name_prefix
#   image_id                    = data.aws_ami.hashistack.id
#   instance_type               = var.instance_type_vault
#   iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
#   key_name                    = var.key_name
#   security_groups             = [aws_security_group.vault.id]
#   associate_public_ip_address = var.public_ip
#   user_data                   = data.template_file.install_vault.rendered
#   enable_monitoring           = var.enable_monitoring # not common
#   spot_price                  = var.spot_price # 0.025
#   ebs_optimized               = var.ebs_optimized # not common

#   root_block_device {
#     # volume_type = "io1"
#     # iops        = "2500" # only for io1 volume_type
#     volume_type = "gp2"
#     volume_size = 50
#   }
  
#   # Required when using a launch configuration with an auto scaling group.
#   # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_autoscaling_group" "consul" {
  name                      = aws_launch_configuration.consul.name
  launch_configuration      = aws_launch_configuration.consul.name
  # availability_zones        = var.azs
  vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
  min_size                  = var.consul_nodes
  max_size                  = var.consul_nodes
  desired_capacity          = var.consul_nodes
  health_check_grace_period = 15
  health_check_type         = "ELB"
  load_balancers            = [aws_elb.consul.id]

  tags = [
    {
      key                 = "Name"
      value               = var.consul_name_prefix
      propagate_at_launch = true
    },
    {
      key                 = "ConsulAutoJoin"
      value               = var.auto_join_tag
      propagate_at_launch = true
    },
    {
      key                 = "owner"
      value               = var.owner
      propagate_at_launch = true
    },
    {
      key                 = "ttl"
      value               = var.ttl
      propagate_at_launch = true
    }
  ]

  lifecycle {
    create_before_destroy = true
  }

  # depends_on = [aws_autoscaling_group.vault]
}

resource "aws_launch_configuration" "consul" {
  name_prefix                 = var.consul_name_prefix
  image_id                    = data.aws_ami.hashistack.id
  instance_type               = var.instance_type_consul
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = var.key_name
  security_groups             = [aws_security_group.vault.id]
  user_data                   = data.template_file.install_consul.rendered
  enable_monitoring           = var.enable_monitoring # not common
  spot_price                  = var.spot_price
  associate_public_ip_address = var.public_ip
  root_block_device {
    # volume_type = "io1"
    volume_type = "gp2"
    volume_size = 100
    # iops        = "5000" # only for io1 volume_type
  }

  lifecycle {
    create_before_destroy = true
  }
}


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
  cidr_blocks       = ["${chomp(data.http.current_ip.body)}/32"]
}

resource "aws_security_group_rule" "vault_8200_in" {
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  # cidr_blocks       = ["0.0.0.0/0"]
  cidr_blocks       = ["${chomp(data.http.current_ip.body)}/32"]
}

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
}