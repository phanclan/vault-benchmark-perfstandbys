data "aws_ami" "hashistack" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = [var.ami]
  }
}

resource "aws_key_pair" "usw2_ec2_key" {
  key_name   = "${var.prefix}-${var.env}-usw2-ec2-key"
  public_key = var.public_key
  # public_key = "${file("~/.ssh/id_rsa.pub")}"    # running locally
}

resource "aws_instance" "servers" {
  count = 0

  ami                    = data.aws_ami.hashistack.id
  instance_type          = var.instance_type_consul
  key_name               = var.key_name
  subnet_id              = element(module.vpc_usw2-1.public_subnets, count.index)
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids = [aws_security_group.vault.id]

  root_block_device {
    # volume_type = "io1"
    # iops        = "5000" # only for io1 volume_type
    volume_type           = "gp2"
    volume_size           = "100"
    delete_on_termination = true # default
  }

  tags = {
    Name  = "${var.prefix}-server-${count.index}"
    owner = var.owner
    # created-by     = var.created-by
    # sleep-at-night = var.sleep-at-night
    # TTL            = var.TTL
    ConsulAutoJoin = var.auto_join_tag
  }

  user_data = data.template_file.install_consul.rendered
}

resource "aws_instance" "workers" {
  count = var.worker_nodes

  ami                    = data.aws_ami.hashistack.id
  instance_type          = var.instance_type_consul
  key_name               = var.key_name
  subnet_id              = element(module.vpc_usw2-1.public_subnets, count.index)
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids = [aws_security_group.vault.id]

  root_block_device {
    # volume_type = "io1"
    # iops        = "5000" # only for io1 volume_type
    volume_type           = "gp2"
    volume_size           = "100"
    delete_on_termination = true # default
  }

  tags = {
    Name  = "${var.prefix}-worker-${count.index}"
    owner = var.owner
    # created-by     = var.created-by
    # sleep-at-night = var.sleep-at-night
    # TTL            = var.TTL
    ConsulAutoJoin = "var.auto_join_tag"
  }

  user_data = data.template_file.install_consul.rendered
}

module "bastion" {
  source = "./modules/services/bastion"
  vpc_id = module.vpc_usw2-1.vpc_id
  # region        = var.region
  instance_type = "t3.small"
  ami           = "pphan*"
  key_name      = "pphan-dev-usw2-ec2-key"
  env           = "dc1"
  owner         = "pphan@hashicorp.com"
  ttl           = local.ttl
  prefix        = "pphan"
  # name_prefix = ""
  subnet_id = module.vpc_usw2-1.public_subnets[0]
  # tf_version     = "0.12.16"
  # vault_version  = "1.3.0"
  # consul_version = "1.6.2"
}

#-------------------------------------------------------------------------------
# AWS EC2 INSTANCE - VAULT
#-------------------------------------------------------------------------------
resource "aws_instance" "vault" {
  count = var.vault_nodes

  ami                    = data.aws_ami.hashistack.id
  instance_type          = var.instance_type_vault
  key_name               = var.key_name
  subnet_id              = element(module.vpc_usw2-1.public_subnets, count.index)
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  vpc_security_group_ids = [aws_security_group.vault.id]

  root_block_device {
    # volume_type = "io1"
    # iops        = "5000" # only for io1 volume_type
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = true # default
  }

  tags = {
    Name  = "${var.prefix}-vault-${count.index}"
    owner = var.owner
    # created-by     = var.created-by
    # sleep-at-night = var.sleep-at-night
    TTL            = var.ttl
    ConsulAutoJoin = "var.auto_join_tag"
  }

  # user_data = data.template_file.install_vault.rendered
  user_data = data.template_cloudinit_config.vault.rendered

  # Consul should be up first.
  depends_on = [module.asg-consul]
}