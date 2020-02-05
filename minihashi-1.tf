# --------------------------------------------------------
# CREATE A NEW NETWORK - VPC, SUBNET'S, GW'S
# --------------------------------------------------------
module "vpc_usw2-2" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "${var.prefix}-${var.env}-usw2-2-vpc-${random_id.env_name.hex}"
  cidr                 = "10.11.0.0/16"
  azs                  = var.azs
  public_subnets       = ["10.11.1.0/24", "10.11.2.0/24", "10.11.3.0/24"]
  private_subnets      = ["10.11.11.0/24", "10.11.12.0/24", "10.11.13.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  # enable_nat_gateway   = true
  # single_nat_gateway = true
  tags                     = local.common_tags
  igw_tags                 = { Name = "${var.prefix}-${var.env}-usw2-2-IGW" }
  nat_gateway_tags         = { Name = "${var.prefix}-${var.env}-usw2-2-NGW" }
  public_route_table_tags  = { Name = "${var.prefix}-${var.env}-usw2-2-RT-public" }
  public_subnet_tags       = { Name = "${var.prefix}-${var.env}-usw2-2-public" }
  private_route_table_tags = { Name = "${var.prefix}-${var.env}-usw2-2-RT-private" }
  private_subnet_tags      = { Name = "${var.prefix}-${var.env}-usw2-2-private" }
}

#------------------------------------------------------------------------------
# AWS SECURITY GROUP - MiniHashi DC2
#------------------------------------------------------------------------------
module "vault-sg" {
  source = "./modules/services/aws-sg"
  vpc_id = module.vpc_usw2-2.vpc_id # not needed
  # cidr = "10.11.0.0/16"
  # public_subnets = ["10.11.1.0/24", "10.11.2.0/24", "10.11.3.0/24"]
  # private_subnets = ["10.11.11.0/24", "10.11.12.0/24", "10.11.13.0/24"]
  ingress_cidr_blocks       = ["10.10.0.0/16", "10.11.0.0/16", "10.12.0.0/16"]
  workstation-external-cidr = local.workstation-external-cidr
  prefix                    = "pphan"
  vault_name_prefix         = "pphan-benchmark-vault"
  # consul_name_prefix = "pphan-benchmark-consul"
  # name_prefix = ""
  tags = {
    Name = "pphan-vault-sg", Owner = "pphan@hashicorp.com"
  }
  # subnet_id = module.vpc_usw2-1.public_subnets[0]
}

#------------------------------------------------------------------------------
# AWS EC2 INSTANCE - MiniHashi DC2
#------------------------------------------------------------------------------
module "minihashi-dc2" {
  source         = "./modules/services/aws-hashimini"
  prefix         = "pphan"
  env            = "dc2"
  nodes          = "1"
  owner          = "pphan@hashicorp.com"
  region         = "us-west-2"
  aws_ami        = data.aws_ami.hashistack.id
  public_subnets = module.vpc_usw2-2.public_subnets
  # private_subnets = module.vpc_usw2-2.private_subnets # Might need later
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  security_group_ids   = module.vault-sg.security_group_id
  # instance_type        = "t3.small" # Maybe remove to default to t3.small for all DR sites
  key_name      = "pphan-dev-usw2-ec2-key"
  tags          = local.common_tags
  auto_join_tag = "pphan-benchmark-cluster"
  zone_id       = var.zone_id # DNS settings
  vault_license = var.vault_license
  # vault_user_data = data.template_file.mini_vault.rendered # moved to module
  # consul_user_data = data.template_file.mini_consul.rendered # moved to module
}

#------------------------------------------------------------------------------
# AWS EC2 INSTANCE - MiniHashi DC3
#------------------------------------------------------------------------------
module "minihashi-dc3" {
  source         = "./modules/services/aws-hashimini"
  prefix         = "pphan"
  env            = "dc3"
  nodes          = "1"
  owner          = "pphan@hashicorp.com"
  region         = "us-west-2"
  aws_ami        = data.aws_ami.hashistack.id
  public_subnets = module.vpc_usw2-2.public_subnets
  # private_subnets = module.vpc_usw2-2.private_subnets # Might need later
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  security_group_ids   = module.vault-sg.security_group_id
  # instance_type        = "t3.small" # Maybe remove to default to t3.small for all DR sites
  key_name      = "pphan-dev-usw2-ec2-key"
  tags          = local.common_tags
  auto_join_tag = "pphan-benchmark-cluster"
  zone_id       = var.zone_id # DNS settings
  vault_license = var.vault_license
  # vault_user_data = data.template_file.mini_vault.rendered # moved to module
  # consul_user_data = data.template_file.mini_consul.rendered # moved to module
}


# --------------------------------------------------------
# CREATE A NEW NLB - VAULT
# --------------------------------------------------------

# module "network_lb" {
#   source                   = "../nlb"
#   nlb_config               = var.test_nlb_config
#   forwarding_config        = var.test_forwarding_config
#   tg_config                = var.test_tg_config
#   vpc_id                   = module.vpc_usw2-2.vpc_id
#   public_subnets           = module.vpc_usw2-2.public_subnets
# }

# // Move the following to variables.tf
# variable "test_nlb_config" {
#   default = {
#     name            = "test-nlb"
#     internal        = "false"
#     environment     = "test"
#     # subnet          = <subnet_id>
#     # nlb_vpc_id      = <vpc_id>
#   }
# }
# variable "test_tg_config" {
#   default = {
#     name                              = "test-nlb-tg"
#     target_type                       = "instance"
#     health_check_protocol             = "TCP"
#     # tg_vpc_id                         = <tg_creation_vpc_id>
#     target_id1                        = <one of instance_id/ip/arn>
#   }
# }
# variable "test_forwarding_config" {
#   default = {
#       8200        = "TCP"
#       # 80        =   "TCP"
#       # 443       =   "TCP" # and so on  }
# }

