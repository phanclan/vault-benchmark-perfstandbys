#!/usr/bin/env bash
set -x
set -e

# Install packages
# ${install_unzip}

# Download Vault into some temporary directory
# curl -L "${vault_download_url}" > /tmp/vault.zip

# Unzip it
# cd /tmp
# sudo unzip vault.zip
# sudo mv vault /usr/local/bin
# sudo chmod 0755 /usr/local/bin/vault
# sudo chown root:root /usr/local/bin/vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

echo "--> Writing vault configuration"
# Setup the configuration
cat <<EOF >/tmp/vault-config
${vault_config}
EOF

sudo mkdir -p /etc/vault.d
sudo mv /tmp/vault-config /etc/vault.d/vault-config.json

echo "#--> Generate systemd configuration"
cat <<EOF >/tmp/systemd
[Unit]
Description=Vault Agent
Requires=consul.service
After=consul.service

[Service]
Restart=on-failure
EnvironmentFile=/etc/vault.d/vault-config.json
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d $FLAGS
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=root
Group=root
LimitMEMLOCK=infinity
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/systemd /etc/systemd/system/vault.service
sudo chmod 0664 /etc/systemd/system/vault.service

# Download Consul into some temporary directory
# curl -L "${consul_download_url}" > /tmp/consul.zip

# Unzip it
# cd /tmp
# sudo unzip consul.zip
# sudo mv consul /usr/local/bin
# sudo chmod 0755 /usr/local/bin/consul
# sudo chown root:root /usr/local/bin/consul

echo "--> Writing consul client configuration"
# Setup the configuration
sudo mkdir -p /etc/consul.d
sudo tee /etc/consul.d/consul-config.json > /dev/null <<"EOF"
{
  "log_level": "INFO",
  "server": false,
  "data_dir": "/opt/consul/data",
  "leave_on_terminate": true,
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
# retry_join - https://www.consul.io/docs/agent/cloud-auto-join.html
# raft_multiplier - https://www.consul.io/docs/agent/options.html#raft_multiplier

IP_ADDRESS=$(curl -s http://instance-data/latest/meta-data/local-ipv4)
sudo sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" /etc/consul.d/consul-config.json
sudo sed -i "s/TAG_VALUE/${tag_value}/g" /etc/consul.d/consul-config.json
# sudo mv /tmp/consul-config /etc/consul.d/consul-config.json

# Setup the init script
cat <<EOF >/tmp/systemd
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
EnvironmentFile=/etc/consul.d/consul-config.json
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d $FLAGS
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=root
Group=root
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/systemd /etc/systemd/system/consul.service
sudo chmod 0664 /etc/systemd/system/consul.service

sudo mkdir -pm 0755 /opt/consul/data

echo "#--> Writing profile"

sudo tee /etc/profile.d/vault.sh > /dev/null <<"EOF"
alias vualt="vault"
export VAULT_ADDR="http://127.0.0.1:8200"
export CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
EOF
source /etc/profile.d/vault.sh

echo "#--> Enable and start Consul and Vault"
# Start Consul
sudo systemctl enable consul
sudo systemctl start consul
# Start Vault
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
