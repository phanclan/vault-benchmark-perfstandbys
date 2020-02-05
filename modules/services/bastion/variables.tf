# aws/modules/uw2/variables.tf
##############################################################################
# Variables File
#
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "prefix" {}
# variable "name_prefix" {}

variable "region" {
  description = "The amazon region to use."
  default     = "us-west-2"
}
variable "vpc_id" {}
variable "instance_type" {}
variable "ami" {}
# variable "vault_cluster_size" {}
# variable "consul_instance_type" {}
# variable "consul_cluster_size" {}
variable "ttl" {}
# variable "uw2-pub-net" {}

# variable "uw2-pri-net" {}

variable "env" {}

variable "owner" {}
# variable "address_space" {}
# variable "subnet_prefix" {}
variable "key_name" {}
variable "subnet_id" {}
variable "private_ip" {}
# variable "tf_version" {}
# variable "vault_version" {}
# variable "consul_version" {}
variable "bastion_nodes" {}