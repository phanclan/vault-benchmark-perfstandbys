#------------------------------------------------------------------------------
# CUSTOMIZATIONS
variable "prefix" {}
variable "env" {}
variable "nodes" {}
variable "owner" {}

#------------------------------------------------------------------------------
# AWS SETTINGS
#------------------------------------------------------------------------------
variable "region" {}
variable "aws_ami" {}
variable "public_subnets" {}
# variable "private_subnets" {}
variable "iam_instance_profile" {}
variable "security_group_ids" {}
variable "instance_type" { default = "t3.small"}
variable "key_name" {}
variable "tags" {}
variable "auto_join_tag" {}
variable "zone_id" {}

#------------------------------------------------------------------------------
# HASHICORP
variable "vault_license" {}
# variable "vault_user_data" {}
# variable "consul_user_data" {}
