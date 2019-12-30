tfclass: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Walkthrough of demo
## Peter Phan, pphan@hashicorp.com

---
name: components
class: compact

# Components

This demo uses multiple HashiCorp products.

- Packer to build the images in AWS
- Terraform to provision the infrastructure
- Vault to demonstrate secrets management
- Nomad to run jobs

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: diagram
class: img-caption

# Diagram

---
name: getting-started
class: img-right

# Getting Started

- Set your variables in `terraform.tfvars`
  - Specify number of nodes desired.
- Run `tf init` and `tf apply`
- See outputs for address information
- Go to websites
  - <http://consul.pphan.hashidemos.io:8500>
  - <http://vault-0.pphan.hashidemos.io:8200>

???

notes

---
name: vault-configuration
class: compact,col-2

# Vault Configuration

- Set your variables in `scripts/env.sh`
- Run `00_fast_setup.sh`
- Get vault admin token.
  - <http://consul.pphan.hashidemos.io:8500/ui/dc1/kv/service/vault/admin-token/edit>
- Log in to Vault UI with admin token
  - <http://vault-0.pphan.hashidemos.io:8200/ui/>
- Test ldap login, db, and transit.
  - `./scripts/test_hr_cloud.sh`
- NOTE: If you want to run this script again, need to reload postgres container.

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
name: packer
# Packer
[the components](#components)

I try to build as much as I can into my gold images and using Packer. This provides the following benefits:
- Consistent builds

--
- Faster deploy times

--
- Consistent images across various clouds
