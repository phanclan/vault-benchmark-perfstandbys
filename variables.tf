#-------------------------------------------------------------------
# Vault settings
#-------------------------------------------------------------------

variable "unzip_command" {
  # Ubuntu: default = "sudo apt-get install -y curl unzip"
  # RedHat: default = "sudo yum -y install unzip"
}

variable "vault_download_url" {
  default     = "https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/1.1.2/vault-enterprise_1.1.2%2Bent_linux_amd64.zip"
  description = "URL to download Vault"
}

variable "consul_download_url" {
  default     = "https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/1.5.0/consul-enterprise_1.5.0%2Bent_linux_amd64.zip"
  description = "URL to download Consul"
}

variable "vault_config" {
  description = "Configuration (text) for Vault"
  default     = <<EOF
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
telemetry {
  prometheus_retention_time = "30s",
  disable_hostname = true
}
ui=true
EOF
}

# Moving the configuration directly into script
variable "consul_server_config" {
  description = "Configuration (text) for Consul"
  default     = <<EOF
{
  "log_level": "INFO",
  "server": true,
  "ui": true,
  "data_dir": "/opt/consul/data",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "advertise_addr": "IP_ADDRESS",
  "bootstrap_expect": CONSUL_NODES,
  "retry_join": ["provider=aws tag_key=ConsulAutoJoin tag_value=TAG_VALUE region=us-west-2"],
  "enable_syslog": true,
  "service": {
    "name": "consul"
  },
  "performance": {
    "raft_multiplier": 1
  },
  "ports": {
    "grpc": 8502
  },
  "connect": {
    "enabled": true
  }
}
EOF
}

# not using this variable. Copied the config directly into script.
variable "consul_client_config" {
  description = "Configuration (text) for Consul"
  default     = <<EOF
{
  "log_level": "INFO",
  "server": false,
  "data_dir": "/opt/consul/data",
  "bind_addr": "IP_ADDRESS",
  "client_addr": "127.0.0.1",
  "retry_join": ["provider=aws tag_key=ConsulAutoJoin tag_value=TAG_VALUE region=us-west-2"],
  "enable_syslog": true,
  "service": {
    "name": "consul-client"
  },
  "performance": {
    "raft_multiplier": 1
  }
}
EOF
}

variable "vault_license" {}


//-------------------------------------------------------------------
// AWS settings
//-------------------------------------------------------------------

variable "region" {}
variable "ami" {
  # Ubuntu 16.04, but could also use ami-059eeca93cf09eebd
  default     = "ami-759bc50a"
  description = "AMI for Vault instances"
}

# might not need this. define in module variables.
variable "public_ip" {
  default     = false
  description = "should ec2 instance have public ip?"
}

variable "vault_name_prefix" {
  description = "prefix used in resource names"
}

variable "consul_name_prefix" {
  description = "prefix used in resource names"
}

variable "availability_zones" {
  description = "Availability zones for launching the Vault instances"
}

variable "vault_elb_health_check" {
  default     = "HTTP:8200/v1/sys/health?standbyok=true&perfstandbyok=true"
  description = "Health check for Vault servers"
}

variable "consul_elb_health_check" {
  default     = "HTTP:8500/v1/agent/self"
  description = "Health check for Consul servers"
}

variable "elb_internal" {
  default     = true
  description = "make ELB internal or external"
}

variable "instance_type_vault" {
  description = "Instance type for Vault instances"
}

variable "instance_type_consul" {
  description = "Instance type for Consul instances"
}

variable "key_name" {
  default     = "default"
  description = "SSH key name for Vault and Consul instances"
}

variable "vault_nodes" {
  description = "number of Vault instances"
}

variable "consul_nodes" {
  description = "number of Consul instances"
}

variable "worker_nodes" {
  description = "number of Consul instances"
}

variable "bastion_nodes" {
  description = "number of Bastion instances"
}

variable "subnets" {
  description = "list of subnets to launch Vault within"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "owner" {
  description = "value of owner tag on EC2 instances"
}

variable "ttl" {
  description = "value of ttl tag on EC2 instances"
}

variable "auto_join_tag" {
  description = "value of ConsulAutoJoin tag used by Consul cluster"
}

variable "prefix" {}
variable "env" {}
variable "public_key" {}


#------------------------------------------------
# Network Variables
#------------------------------------------------
variable "cidr" { default = "10.10.0.0/16" }
variable "azs" {}
variable "public_subnets" {
  default = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}
variable "private_subnets" {
  default = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
}
variable "private_ips" {
  default = {
    "10.10.11.10" = 1
    "10.10.11.10" = 2
    "10.10.11.10" = 3
  }
}
variable "bastion_private_ip" {
  default = "10.10.1.10"
}

variable "zone_id" {}
variable "spot_price" {
  default = "0.025"
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "ebs_optimized" {
  default = false
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "for security group rules"
  default     = ["10.10.1.0/24", "10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
}
