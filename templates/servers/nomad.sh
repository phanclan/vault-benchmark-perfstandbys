#!/usr/bin/env bash
echo "==> Nomad (server)"

echo "--> Fetching"

echo "--> Generating Vault token..."

echo "--> Create Directories to Use as a Mount Targets"
sudo mkdir -p /opt/postgres/data/
sudo mkdir -p /opt/mysql/data/
sudo mkdir -p /opt/mongodb/data/
sudo mkdir -p /opt/prometheus/data/

echo "--> Installing CNI plugin"

echo "--> Writing configuration"
sudo mkdir -p /mnt/nomad
sudo mkdir -p /etc/nomad.d
sudo tee /etc/nomad.d/config.hcl > /dev/null <<EOF
#--> Increase log verbosity
log_level = "DEBUG"

#--> Setup data dir
data_dir = "/mnt/nomad"

#--> Give the agent a unique name. Defaults to hostname
# name = "client1"

#--> Enable the server
server {
    enabled = true

    # Self-elect, should be 3 or 5 for production
    bootstrap_expect = 3
}
# leave_on_interrupt = true
# leave_on_terminate = true

#--> Enable the client
client {
    enabled = true

    # For demo assume we are talking to server1. For production,
    # this should be like "nomad.service.consul:4647" and a system
    # like Consul used for service discovery.
    # servers = ["127.0.0.1:4647"]
}

# Telemetry
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
EOF

echo "--> Writing profile"
sudo tee /etc/profile.d/nomad.sh > /dev/null <<"EOF"
alias noamd="nomad"
alias nomas="nomad"
alias nomda="nomad"
EOF
source /etc/profile.d/nomad.sh

echo "--> Generating systemd configuration"
sudo tee /etc/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
Environment=VAULT_TOKEN=$NOMAD_VAULT_TOKEN
ExecStart=/usr/local/bin/nomad agent -config="/etc/nomad.d"
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable nomad
sudo systemctl start nomad
sleep 2

echo "--> Waiting for all Nomad servers"

echo "--> Waiting for Nomad leader"
while [ -z "$(curl -s http://localhost:4646/v1/status/leader)" ]; do
  sleep 5
done

echo "--> Create sql init file for postgres container"
tee /opt/postgres/data/sql/init.sql <<"EOF"
CREATE USER vault_admin WITH SUPERUSER CREATEROLE PASSWORD 'notsosecure';
CREATE DATABASE mother;

\c mother

CREATE SCHEMA it;
CREATE SCHEMA hr;
CREATE SCHEMA security;
CREATE SCHEMA finance;
CREATE SCHEMA engineering;

ALTER ROLE postgres SET search_path TO public,it,hr,security,finance,engineering;
ALTER ROLE vault_admin SET search_path TO public,it,hr,security,finance,engineering;

GRANT ALL PRIVILEGES ON ALL TABLES 
IN SCHEMA public,it,hr,security,finance,engineering 
TO vault_admin 
WITH GRANT OPTION;

\c mother vault_admin

CREATE TABLE hr.people (
  email       varchar(40),
  id          varchar(255),
  id_type     varchar(40),
  first_name  varchar(40),
  last_name   varchar(40)
);

INSERT INTO hr.people VALUES
  ('alice@ourcorp.com', '123-45-6789', 'ssn', 'Alice', 'Enshanes'),
  ('bob@ourcorp.com', '234-56-7890', 'ssn', 'Bob', 'Paulson'),
  ('chun@ourcorp.com', '350322197001015332', 'cric', 'Chun', 'Li'),
  ('deepak@ourcorp.com', '0123 4567 8901', 'uidai', 'Deepak', 'Singh'),
  ('eve@ourcorp.com', 'AB 12 34 56 Z', 'nino', 'Eve', 'Darknight'),
  ('frank@ourcorp.com', '678-90-1234', 'ssn', 'Frank', 'Franklin')
;


CREATE TABLE engineering.catalog (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR (60),
  description   VARCHAR (255),
  currency      VARCHAR (40),
  price         NUMERIC (12,2)
);

INSERT INTO engineering.catalog (name, description, currency, price) 
   VALUES
  ('Thromdibulator', 'Complex machine, do not disassemble', 'usd', '100.00'),
  ('Visi-Sonor', 'Musical instrument with visualizations', 'usd', '20000.00'),
  ('Deep Thought', 'Super Computer', 'gbp', '4242424242.42'),
  ('Mithril Vest', 'Very Good Armor (TM)', 'gbp', '12345678.90'),
  ('Blaine the Mono', 'Psychopathic train, enjoys proper riddles', 'usd', '9600000.96'),
  ('Millennium Falcon', 'Fastest Hunk-of-Junk in the Galaxy', 'cred', '421000.00'),
  ('Sonic Screwdriver', 'Multi-tool', 'gbp', '999999999.99')
;
EOF

echo "==> Nomad is done!"
