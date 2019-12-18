#!/bin/bash

tput clear
cyan "#-------------------------------------------------------------------------------
#--- Setup PERFORMANCE replication (vault1 -> vault2)
#-------------------------------------------------------------------------------\n"

# VAULT_PRIMARY_CLUSTER_ADDR=http:://vault1:8201
green "#--- Enable Performance Replication on Primary Cluster"
vault login root
pe "vault write -f sys/replication/performance/primary/enable"
# vault_primary write -f /sys/replication/performance/primary/enable primary_cluster_addr=${VAULT_PRIMARY_CLUSTER_ADDR}
sleep 10
# http://localhost:8200/ui/vault/replication
# Cluster mode: primary
# Click Enable Replication

echo
cyan "#-------------------------------------------------------------------------------
# Fetch a secondary token
#-------------------------------------------------------------------------------\n"
green "#--- To fetch a secondary bootstrap token"
# PRIMARY_PERF_TOKEN=$(vault write -format=json sys/replication/performance/primary/secondary-token id=vault2 \
  # | jq --raw-output '.wrap_info .token' )
vault write -format=json sys/replication/performance/primary/secondary-token id=vault2 | tee /tmp/perf-secondary-token.txt
PRIMARY_PERF_TOKEN=$(jq -r '.wrap_info.token' /tmp/perf-secondary-token.txt)
vault read sys/replication/performance/status

# http://localhost:8200/ui/vault/replication/performance/secondaries
# Add secondary. Specify Secondary ID. Click Generate token.


# Note to revoke a token
# vault write -format=json /sys/replication/performance/primary/revoke-secondary id=vault2


echo
cyan "#-------------------------------------------------------------------------------
# ENABLE PR SECONDARY CLUSTER (vault2)
#-------------------------------------------------------------------------------\n"
green "From secondary node, activate a secondary using the fetched token."
vault2 login root
vault2 write sys/replication/performance/secondary/enable token=${PRIMARY_PERF_TOKEN}

cyan "#-------------------------------------------------------------------------------
# VALIDATION
#-------------------------------------------------------------------------------\n"

green "#--- Validate from vault1"
curl -s http://127.0.0.1:8200/v1/sys/replication/status | jq .data

green "#--- Validate from vault2"
curl -s http://127.0.0.1:8202/v1/sys/replication/status | jq .data

yellow "Observe that the cluster ids are the same when you run replicatiin status on 
both clusters. Pay attention to mode, primary cluster address, and secondary list"
