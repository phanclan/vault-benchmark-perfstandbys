#!/bin/bash
# VAULT_VERSION="1.0.2"
# VAULT_DOWNLOAD="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
CONSUL_TEMPLATE_VERSION="0.21.2"
CONSUL_TEMPLATE_DOWNLOAD="https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip"
ENVCONSUL_VERSION="0.9.0"
ENVCONSUL_DOWNLOAD="https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip"


# Download and install Vault, consul-template and envconsul
# curl -so vault.zip ${VAULT_DOWNLOAD}
curl -so /tmp/consul-template.zip ${CONSUL_TEMPLATE_DOWNLOAD}
curl -so /tmp/envconsul.zip ${ENVCONSUL_DOWNLOAD}

sudo unzip -d /usr/local/bin /tmp/consul-template.zip
sudo unzip -d /usr/local/bin /tmp/envconsul.zip

sudo apt-get install -y mysql-server