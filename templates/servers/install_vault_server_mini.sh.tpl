#!/usr/bin/env bash
set -x
set -e

IP_ADDRESS=$(curl -s http://instance-data/latest/meta-data/local-ipv4)

echo "#==> CONFIGURE CONSUL CLIENT START"

# sudo chmod 0755 /usr/local/bin/consul
# sudo chown root:root /usr/local/bin/consul

echo "--> CREATE CONSUL CLIENT CONFIG FILE"
sudo mkdir -pm 0755 /opt/consul/data
sudo mkdir -pm 0755 /etc/consul.d
sudo tee /etc/consul.d/consul-config.json > /dev/null <<"EOF"
{
  "datacenter": "${env}",
  "log_level": "INFO",
  "server": false,
  "data_dir": "/opt/consul/data",
  "leave_on_terminate": true,
  "bind_addr": "IP_ADDRESS",
  "client_addr": "127.0.0.1",
  "retry_join": ["provider=aws tag_key=ConsulAutoJoin tag_value=TAG_VALUE"],
  "enable_syslog": true,
  "service": {
    "name": "consul-client"
  },
  "performance": {
    "raft_multiplier": 1
  }
}
EOF
# retry_join - https://www.consul.io/docs/agent/cloud-auto-join.html
# raft_multiplier - https://www.consul.io/docs/agent/options.html#raft_multiplier

sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" /etc/consul.d/consul-config.json
sudo sed -i "s/TAG_VALUE/${tag_value}/g" /etc/consul.d/consul-config.json
# sudo mv /tmp/consul-config /etc/consul.d/consul-config.json

echo "#--> Generate systemd configuration"
sudo tee /etc/systemd/system/consul.service <<EOF
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Restart=on-failure
EnvironmentFile=/etc/consul.d/consul-config.json
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d $FLAGS
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0664 /etc/systemd/system/consul.service

echo "#--> Writing profile"

sudo tee /etc/profile.d/vault.sh > /dev/null <<"EOF"
alias vualt="vault"
export VAULT_ADDR="http://127.0.0.1:8200"
export CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
EOF
source /etc/profile.d/vault.sh

echo "#==> START CONSUL CLIENT"
sudo systemctl enable consul
sudo systemctl start consul
# Give time for consul to start since Vault depends on it.
# sleep 8

echo "#== CONFIGURE CONSUL CLIENT FINISHED"

#------------------------------------------------------------------------------

echo "#==> CONFIGURE VAULT CLIENT START"

sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

echo "--> CREATE VAULT CONFIG FILE"
sudo mkdir -p /etc/vault.d
# sudo chown --recursive vault:vault /etc/vault.d
sudo tee /etc/vault.d/config.hcl > /dev/null <<EOF
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
  # tls_cert_file = "/etc/vault.d/tls/vault.crt"
  # tls_key_file  = "/etc/ssl/certs/me.key"
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
# HA Parameters
api_addr = "https://$(public_ip):8200"
EOF
# public_ip is a function defined in base.sh
sudo chmod 640 /etc/vault.d/config.hcl
# sudo mv /tmp/vault-config /etc/vault.d/vault-config.json

echo "#--> Generate systemd configuration"
sudo tee /etc/systemd/system/vault.service <<EOF
[Unit]
Description=Vault Agent
Requires=consul.service
After=consul.service
ConditionFileNotEmpty=/etc/vault.d/config.hcl

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/vault server -config /etc/vault.d/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
Restart=on-failure
TimeoutStopSec=30
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0664 /etc/systemd/system/vault.service


echo "#==> START VAULT"
sudo systemctl enable vault
sudo systemctl start vault

echo "#--> CHECK FOR CONSUL"
while ! nslookup consul-client.service.consul;
do
  echo "Consul is not available yet"
  sleep 2
done
echo "Consul is available"

echo "#--> INITIALIZE VAULT"
sleep 5
while ! vault operator init -status > /dev/null
do
consul lock tmp/vault/lock "$(cat <<"EOF"
sleep 2
vault operator init -key-shares=1 -key-threshold=1 -format=json | sudo tee /tmp/vault.init
jq -r ".unseal_keys_b64[0]" /tmp/vault.init | consul kv put service/vault/recovery-key -
consul kv get service/vault/recovery-key
jq -r ".root_token" /tmp/vault.init | consul kv put service/vault/root-token -
consul kv get service/vault/root-token
EOF
)"
done

echo "#--> UNSEAL VAULT"
sleep 4
curl -X PUT -d '{"key": "'"$(consul kv get service/vault/recovery-key)"'"}' \
    ${VAULT_ADDR}/v1/sys/unseal

echo "#--> LICENSE VAULT"
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
echo $VAULT_TOKEN
echo "#--> Display Vault license"
echo ${vault_license}
echo $VAULT_ADDR
vault write sys/license text=${vault_license}
if vault read sys/license
then
echo "#--> LICENSE APPLIED"
else
echo "Not"
fi

echo "#--> ENABLE AUDIT LOG - RAW"
vault audit enable file file_path=/tmp/audit-1.log log_raw=true

echo "#== CONFIGURE VAULT FINISHED"
