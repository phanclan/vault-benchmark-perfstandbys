name: demo-walkthrough
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)

# Demo Walkthrough

## Peter Phan, pphan@hashicorp.com

![:scale 15%](images/HashiCorp_Icon_White.png)

---
name: components
class: compact

# Components

This demo uses multiple HashiCorp products.

- [Packer](#packer) to build the images in AWS
- [Terraform](#terraform) to provision the infrastructure
- Vault to demonstrate secrets management
- Nomad to run jobs

---
layout: true

.footer[
- Copyright © 2020 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: diagram
class: img-caption

# Diagram

---
name: instances
class: compact

# Instances

.smaller[
| Name     |  Zones | Comments
| -------- | --------  | ---
| bastion | public | postgres, openldap
]

---
name: firewall-rules-bastion
class: compact

# SG Rules - bastion

.smaller[
| Name     |  Zones | Rule | Port | Protocol | CIDR/SG
| -------- | -------- | --- |:---:|:---:|
| bastion | ingress | allow_ssh_inbound | 22 | tcp | local.all_ips
| bastion | ingress | allow_http_inbound | 80 | tcp | local.all_ips
| bastion | ingress | allow_https_inbound | 443 | tcp | local.all_ips
| bastion | ingress | allow_postgres_in | 5432 | tcp | ${chomp(data.http.current_ip.body)}/32
| bastion | ingress | allow_internal_in | 0 | -1 | local.internal_ips
| bastion | egress | allow_all_outbound | 0 | -1 | local.all_ips
]

???

internal_ips      = ["10.10.0.0/16"]

---
name: firewall-rules-hashi
class: compact

# SG Rules - aws-sg

.smaller[
| Name     |  Zones | Rule | Port | Protocol | CIDR/SG
| -------- | -------- | --- |:---:|:---:|
| vault | ingress | vault_8200_in | 8200 | tcp | my_ip
| vault | ingress | consul_vault_in | 8000-9200 | tcp | my_ip, ingress_cidr_blocks
| vault | ingress | consul_vault_in_sg | 8000-9200 | tcp | aws-sg
| vault | ingress | nomad_in | 4646-4648 | tcp | my_ip, ingress_cidr_blocks
| vault | ingress | nomad_in | 4646-4648 | tcp | aws-sg
]

???

might need a rule for 8600 UDP - Consul DNS, 8301-8302/UDP - Consul Serf


---
class: compact

.smaller[
| Name | Zones | Rule | Port | Protocol | CIDR/SG | Comments
| --- | --- | --- |:---:|:---:|
| vault | ingress | ssh_in | 22 | tcp | my_ip
| vault | ingress | http_in | 80 | tcp | local.all_ips | need to add
| vault | ingress | https_in | 443 | tcp | local.all_ips | need to add
| vault | ingress | postgres_in | 5432 | tcp | my_ip
| vault | ingress | prometheus_vault_in | 9998 | tcp | my_ip, ingress_cidr_blocks
| vault | egress | hashi_any_out | 0 | -1 | 0/0
]
<!-- | vault | ingress | allow_internal_in | 0 | -1 | local.internal_ips -->

???

internal_ips      = ["10.10.0.0/16"]

---

# Required Ports for Hashi

.smaller[
| Name | Port | Protocol | Direction | Comments |
| --- | --- | --- |:---:|:---:|
| vault cluseter | 8201 | tcp | server --> server
| consul dns | 8600 | tcp/udp | client --> server
| consul rpc | 8300-8300 | tcp | client --> server
| consul serf | 8301-8302 | tcp/udp | server --> server

]

---
name: getting-started
class: img-right

![steps](images/jukan-tateisi-bJhT_8nbUA0-unsplash.jpg)

# Getting Started

- Modify `terraform.tfvars` to set node counts, types, etc.
- Configure Vault.
- Configure Nomad

---
name: terraform.tfvars

# Configure terraform.tfvars

- Set your variables in `terraform.tfvars`
- Specify number of nodes desired.
  - Required: `consul_nodes` = "3"
  - If you want **Vault**, then:
    - `vault_nodes` = "1" or "3"
    - `bastion_nodes` = "1"
- See slide notes.

???

- The bastion nodes run postgres and openldap containers for vault demos.

---
name: terraform
class: compact, col-2

# Run terraform

- Run `terraform init` and `terraform apply`
- Go to websites
.smaller[
- <http://consul.pphan.hashidemos.io:8500>
- <http://vault-0.pphan.hashidemos.io:8200>
]
- See terraform outputs for address information
- Sample Output
```shell
consul_address = http://pphan-benchmark-consul-elb-415011961.us-west-2.elb.amazonaws.com:8500
consul_ui = http://consul.pphan.hashidemos.io:8500
hashi-bastion = []
hashi-servers = []
hashi-vault = [
  "vault-0.pphan.hashidemos.io",
  "vault-1.pphan.hashidemos.io",
]
hashi-workers = []
vault_address = http://pphan-benchmark-vault-elb-1577691433.us-west-2.elb.amazonaws.com:8200
vault_elb_security_group = sg-08eb784c4545cbbe0
vault_security_group = sg-064459f68e6d2de6a
vault_ui = http://vault.pphan.hashidemos.io:8200
```

???

- An `apply` takes about 1.5 minutes.
- A `destroy` takes about 5.5 minutes.

---
class: compact

# Terrform Output Example

```shell
Outputs:
consul_address = http://pphan-benchmark-consul-elb-233529192.us-west-2.elb.amazonaws.com:8500
consul_ui = http://consul.pphan.hashidemos.io:8500
hashi-bastion = []
hashi-servers = []
hashi-vault = []
hashi-workers = []
vault_address = http://pphan-benchmark-vault-elb-1782785251.us-west-2.elb.amazonaws.com:8200
vault_elb_security_group = sg-08a7b92e27ba9909f
vault_security_group = sg-086ff9c44564c1693
vault_ui = http://vault.pphan.hashidemos.io:8200
```

---
class: compact, col-2

# How to Connect

.smaller[
- If this is not the first time connecting, you might need to clear out your ssh `known_hosts` file.
- `sed -i.bak '/pphan.hashidemos.io/d' ~/.ssh/known_hosts`
- ASG Instances: Need to find their IP's. The config currently does create DNS entries for the ASG.]

```shell
aws --region us-west-2 \
  ec2 describe-instances --filter Name=tag-key,Values=aws:autoscaling:groupName \
  --query 'Reservations[*].Instances[*].{Instance:InstanceId,AZ:Placement.AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value,PIP:PublicIpAddress}' \
  --output text | grep pphan | grep -iv "None" | tee /tmp/describe-instances.txt

# Sample Output
us-west-2a      i-081032ddbd90603f2     pphan-benchmark-consul  54.184.117.73
us-west-2b      i-08ff2beb381b127dc     pphan-benchmark-consul  52.27.233.72
us-west-2c      i-0d684129fa2017004     pphan-benchmark-consul  18.237.139.94
```

- Connect to the host
```shell
ssh ubuntu@54.184.117.73
```
- Verify base functionality
```shell
consul members
nomad server members
nomad node status
```

???

- For the known_hosts file, I am removing entries that have my demo domain name. You will need to specify your own domains and IP's as well.
- You can also find IP's from AWS Console: https://console.aws.amazon.com
- Sample Output - Verify base functionality

```shell
$ consul members
Node            Address           Status  Type    Build  Protocol  DC   Segment
ip-10-10-1-196  10.10.1.196:8301  alive   server  1.6.2  2         dc1  <all>
ip-10-10-2-42   10.10.2.42:8301   alive   server  1.6.2  2         dc1  <all>
ip-10-10-3-17   10.10.3.17:8301   alive   server  1.6.2  2         dc1  <all>
ip-10-10-1-11   10.10.1.11:8301   alive   client  1.6.2  2         dc1  <default>

$ nomad server members
Name                   Address      Port  Status  Leader  Protocol  Build   Datacenter  Region
ip-10-10-1-196.global  10.10.1.196  4648  alive   false   2         0.10.2  dc1         global
ip-10-10-2-42.global   10.10.2.42   4648  alive   true    2         0.10.2  dc1         global
ip-10-10-3-17.global   10.10.3.17   4648  alive   false   2         0.10.2  dc1         global

$ nomad node status
ID        DC   Name            Class   Drain  Eligibility  Status
a232963a  dc1  ip-10-10-1-196  <none>  false  eligible     ready
fef17726  dc1  ip-10-10-2-42   <none>  false  eligible     ready
c1091995  dc1  ip-10-10-3-17   <none>  false  eligible     ready
```

---
class: compact

# Troubleshooting

- Verify that there are no errors on boot strap.
```shell
less /var/log/cloud-init-output.log
```

---
name: vault-configuration
class: compact,col-2

# Vault Configuration

This section configures Vault with our demo configurations.

.smaller[
- Set your variables in `scripts/env.sh`
- Run `00_fast_setup.sh`
- Get vault admin token.
  - <http://consul.pphan.hashidemos.io:8500/ui/dc1/kv/service/vault/admin-token/edit>
- Log in to Vault UI with admin token
  - <http://vault-0.pphan.hashidemos.io:8200/ui/>
- Test ldap login, db, and transit.
  - `./scripts/test_hr_cloud.sh`
- NOTE: If you want to run this script again, need to reload postgres container.
]

``` shell
ssh ubuntu@bastion.pphan.hashidemos.io
#--> Go to vault repo that you cloned
cd /tmp/vault-benchmark-perfstandbys/
#--> Stop and start container
*docker-compose down; docker-compose up -d postgres
```

---

- Lab Only Parameters
  - `VAULT_SKIP_VERIFY`: Do not verify Vault's presented certificate before communicating with it.

---
name: vault-sample-configuration
class: compact, col-2
# Vault Sample Configuration
code doesn't work well with two columns
``` go
cluster_name = "${namespace}-demostack"
storage "consul" {
  path = "vault/"
  service = "vault"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/ssl/certs/me.key"
   tls-skip-verify = true
}
seal "awskms" {
  region = "${region}"
  kms_key_id = "${kmskey}"
}
telemetry {
  prometheus_retention_time = "30s",
  disable_hostname = true
}
api_addr = "https://$(public_ip):8200"
disable_mlock = true
ui = true
```

---
name: demo-shutdown
class: compact, col-2
# Demo Shutdown and/or Rebuild

```shell
terraform destroy
```

- Rebuild bastion
```shell
terraform taint "aws_instance.bastion[0]"
terraform apply -auto-approve
```

- Rebuild vault
```shell
for i in {1..3}; do
terraform taint "aws_instance.vault[$i]"
done
```

---

# Next Steps

- [Vault](vault.html)
- [Nomad](nomad.html)
- [Consul](consul.html)