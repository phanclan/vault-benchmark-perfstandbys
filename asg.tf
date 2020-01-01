#-------------------------------------------------------------------------------
# LAUNCH CONFIGURATION AND AUTOSCALING GROUP - VAULT
#-------------------------------------------------------------------------------
# module "asg-vault" {
#   source = "./modules/services/aws-autoscaling"

#   name = "pphan-benchmark-vault"

#   #--- Launch configuration
#   #------------------------
#   # create_lc = false # disables creation of launch configuration
#   lc_name = "pphan-benchmark-vault-lc"

#   image_id                     = data.aws_ami.hashistack.id
#   instance_type                = var.instance_type_vault
#   iam_instance_profile         = aws_iam_instance_profile.instance_profile.name
#   key_name                     = var.key_name
#   security_groups              = [aws_security_group.vault.id]
#   associate_public_ip_address  = true
#   user_data                    = data.template_file.install_vault.rendered
#   enable_monitoring            = false # not common
#   spot_price                   = var.spot_price # 0.025
#   ebs_optimized                = var.ebs_optimized # not common
#   # recreate_asg_when_lc_changes = true

#   root_block_device = [
#     {
#       # volume_type = "io1"
#       # iops        = "2500" # only for io1 volume_type
#       volume_type           = "gp2"
#       volume_size           = "50"
#       delete_on_termination = true
#     },
#   ]

#   # Auto scaling group
#   #-------------------
#   asg_name                  = "pphan-benchmark-vault" # CHANGE
#   vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
#   health_check_type         = "EC2" # ELB health check triggers failure loop
#   min_size                  = 0
#   max_size                  = var.vault_nodes
#   desired_capacity          = var.vault_nodes
#   health_check_grace_period = 15
#   wait_for_capacity_timeout = 0 # default is 10m
#   # service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
#   # Currently, load balancer config is included with ASG module.
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
#     },
#     {
#       key                 = "Environment"
#       value               = "dev"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "Project"
#       value               = "Vault Benchmark"
#       propagate_at_launch = true
#     },
#   ]
# }

#-------------------------------------------------------------------------------
# LAUNCH CONFIGURATION AND AUTOSCALING GROUP - CONSUL
#-------------------------------------------------------------------------------

module "asg-consul" {
  source = "./modules/services/aws-autoscaling"

  name = "pphan-benchmark-consul"

  #--- Launch configuration
  #------------------------
  # create_lc = false # disables creation of launch configuration
  lc_name = "pphan-benchmark-vault-lc"

  image_id                    = data.aws_ami.hashistack.id
  instance_type               = var.instance_type_consul
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = var.key_name
  security_groups             = [aws_security_group.vault.id]
  associate_public_ip_address = true
  user_data                   = data.template_file.install_consul.rendered
  enable_monitoring           = false             # not common
  spot_price                  = var.spot_price    # 0.025
  ebs_optimized               = var.ebs_optimized # not common
  # recreate_asg_when_lc_changes = true

  root_block_device = [
    {
      # volume_type = "io1"
      # iops        = "5000" # only for io1 volume_type
      volume_type           = "gp2"
      volume_size           = "100"
      delete_on_termination = true # default
    },
  ]

  # Auto scaling group
  #-------------------
  asg_name                  = "pphan-benchmark-consul" # CHANGE
  vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
  health_check_type         = "ELB"
  min_size                  = 3
  max_size                  = var.consul_nodes
  desired_capacity          = var.consul_nodes
  health_check_grace_period = 15
  wait_for_capacity_timeout = 0 # default is 10m
  # service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  # Currently, load balancer config is included with ASG module.
  load_balancers = [aws_elb.consul.id] # only for elb. alb use target_group_arns

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
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "Vault Benchmark"
      propagate_at_launch = true
    },
  ]
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


# resource "aws_autoscaling_group" "consul" {
#   name                      = aws_launch_configuration.consul.name
#   launch_configuration      = aws_launch_configuration.consul.name
#   # availability_zones        = var.azs
#   vpc_zone_identifier       = module.vpc_usw2-1.public_subnets
#   min_size                  = var.consul_nodes
#   max_size                  = var.consul_nodes
#   desired_capacity          = var.consul_nodes
#   health_check_grace_period = 15
#   health_check_type         = "ELB"
#   load_balancers            = [aws_elb.consul.id]

#   tags = [
#     {
#       key                 = "Name"
#       value               = var.consul_name_prefix
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
#     {
#       key                 = "Environment"
#       value               = "dev"
#       propagate_at_launch = true
#     },
#     {
#       key                 = "Project"
#       value               = "Vault Benchmark"
#       propagate_at_launch = true
#     },
#   ]

#   lifecycle {
#     create_before_destroy = true
#   }

#   # depends_on = [aws_autoscaling_group.vault]
# }

# resource "aws_launch_configuration" "consul" {
#   name_prefix                 = var.consul_name_prefix
#   image_id                    = data.aws_ami.hashistack.id
#   instance_type               = var.instance_type_consul
#   iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
#   key_name                    = var.key_name
#   security_groups             = [aws_security_group.vault.id]
#   user_data                   = data.template_file.install_consul.rendered
#   enable_monitoring           = var.enable_monitoring # not common
#   spot_price                  = var.spot_price
#   associate_public_ip_address = var.public_ip
#   root_block_device {
#     # volume_type = "io1"
#     volume_type = "gp2"
#     volume_size = 100
#     # iops        = "5000" # only for io1 volume_type
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }
