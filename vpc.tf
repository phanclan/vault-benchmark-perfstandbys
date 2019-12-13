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
