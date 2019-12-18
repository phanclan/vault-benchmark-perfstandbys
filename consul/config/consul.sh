#!/bin/bash
# This scripts builds the configurations for the consul servers and clients.
# Certail values were intentionally left out so they can be called from CLI.

IP=$(hostname -i | awk '{print $1}')
#------------------------------------------------------------------------------
# BUILD CONSUL SERVER CONFIGURATION
#------------------------------------------------------------------------------
# sudo mkdir -p /mnt/consul
# Created by dockerfile
mkdir -p /etc/consul.d
chmod a+w /etc/consul.d

# tee /consul/config/config.json > /dev/null <<EOF
# {
#   "datacenter": "dc1",
#   "data_dir": "/consul/data",
#   "bind_addr": "0.0.0.0",
#   "client_addr": "0.0.0.0",
#   "ui": true,
#   "log_level": "DEBUG",
#   "retry_join": [
#     "cc1s1",
#     "cc1s2",
#     "cc1s3"
#   ],
#   "ports": {
#     "grpc": 8502
#   },
#   "connect": {
#     "enabled": true
#   },
#   "enable_local_script_checks": true
# }
# EOF

# Removed "server": true, - manually call from docker-compose.
# Following folders are ephemeral: data_dir
# Following folders are mounted: /consul/config, 


#------------------------------------------------------------------------------
# WRITE PROFILE
#------------------------------------------------------------------------------
tee /etc/profile.d/consul.sh > /dev/null <<"EOF"
alias conslu="consul"
alias ocnsul="consul"
EOF
source /etc/profile.d/consul.sh


#------------------------------------------------------------------------------
# DNSMASQ
#------------------------------------------------------------------------------

apt-get install -y dnsmasq
tee /etc/dnsmasq.d/10-consul > /dev/null <<EOF
server=/consul/127.0.0.1#8600
no-poll
server=127.0.0.11
server=8.8.8.8
cache-size=0
EOF

# Docker - need server=127.0.0.11 to resolve other containers.

# Need the following for Ubuntu container else dnsmasq will not start.
sed -i -e 's/#user=/user=root/' /etc/dnsmasq.conf

# Start the service
service dnsmasq start

# dig @127.0.0.1 -p 8600 active.vault.service.consul

