FROM ubuntu:18.04

ARG TERRAFORM_VERSION=0.12.16
ARG VAULT_VERSION=1.3.0
ARG CONSUL_VERSION=1.6.2
ARG NOMAD_VERSION=0.10.1
ARG CONSUL_TEMPLATE_VERSION=0.23.0
ARG ENVCONSUL_VERSION=0.9.1

RUN apt-get update && \
    apt-get install -y apache2 \
    jq unzip tree curl wget git pv make \
    nginx
    # apt-get clean && rm -rf /var/lib/apt/lists/*
RUN apt-get install -y vim \
    dnsutils \
    iputils-ping \
    net-tools \
    netcat
# resolvconf causes problems
# RUN apt-get install -y resolvconf
RUN curl -s -o /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}+ent/vault_${VAULT_VERSION}+ent_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/vault.zip && \
    vault -autocomplete-install && \
    curl -s -o /tmp/consul.zip https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/consul.zip && \
    curl -s -o /tmp/nomad.zip https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/nomad.zip && \
    curl -s -o /tmp/consul-template.zip https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/consul-template.zip && \
    curl -s -o /tmp/envconsul.zip https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/envconsul.zip
RUN curl -s -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip -qqo -d /usr/local/bin/ /tmp/terraform.zip
RUN git clone https://github.com/phanclan/demo-vault-202.git /tmp/workstation/vault && \
    mkdir -p /tmp/workstation/vault/raft-node2 /tmp/workstation/vault/raft-node3 /vault && \
    mkdir -p /consul

# COPY ./config/vault1-config.hcl /vault/config/vault1-config.hcl

EXPOSE 8200 8500 8600

# ENTRYPOINT ["vault"]
    
# net-tools for netstat. netstat -ltunp