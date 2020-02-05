#!/usr/bin/env bash
# set -e

#--> CREATE CONSUL SERVER CONFIGURATION
sudo mkdir -p /mnt/consul
sudo mkdir -p /etc/consul.d

cat <<EOF >/tmp/consul-config
{
  "datacenter": "${env}",
  "log_level": "INFO",
  "server": true,
  "ui": true,
  "data_dir": "/opt/consul/data",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "advertise_addr": "$(private_ip)",
  "bootstrap_expect": CONSUL_NODES,
  "retry_join": ["provider=aws tag_key=ConsulAutoJoin tag_value=TAG_VALUE"],
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
sed -i 's/CONSUL_NODES/${consul_nodes}/g' /tmp/consul-config
sudo mv /tmp/consul-config /etc/consul.d/consul-config.json

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

# Start Consul
sudo systemctl enable consul
sudo systemctl start consul
