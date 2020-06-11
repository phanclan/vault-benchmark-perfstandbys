#!/bin/bash
# From vault guide
. env.sh
set -e

# cyan "Create interfaces if running on one Ubuntu machine"
# pe "sudo ifconfig lo:0 127.0.0.2
# sudo ifconfig lo:1 127.0.0.3
# sudo ifconfig lo:2 127.0.0.4"

# VAULT1=127.0.0.1
# VAULT2=127.0.0.2
# VAULT3=127.0.0.3
# VAULT4=127.0.0.4
VAULT1=127.0.0.1
VAULT2=127.0.0.1
VAULT3=127.0.0.1
VAULT4=127.0.0.1



# unset VAULT_TOKEN
vault_1() {
    VAULT_ADDR=http://127.0.0.1:8200 vault $@
}

vault_2() {
    VAULT_ADDR=http://127.0.0.1:10101 vault $@
}

vault_3() {
    VAULT_ADDR=http://127.0.0.1:10102 vault $@
}

vault_4() {
    VAULT_ADDR=http://127.0.0.1:10103 vault $@
}

mkdir -p /tmp/raft-test
TEST_HOME=/tmp/raft-test

# cyan "#-------------------------------------------------------------------------------
# # Step 1: Configure Auto-unseal Key Provider (vault1)
# #-------------------------------------------------------------------------------\n"
# echo
# cyan "Create configuration for vault1"
# tee $TEST_HOME/config-vault1.hcl <<EOF
# storage "inmem" {}
# listener "tcp" {
#   address = "127.0.0.1:8200"
#   tls_disable = true
# }
# EOF
# p "Press Enter"

##########################################################################################
# vault1
##########################################################################################

# cyan "Start vault1"
# pe "export VAULT_ADDR=http://${VAULT1}:8200"
# pe "VAULT_API_ADDR=http://${VAULT1}:8200 vault server -log-level=trace -config $TEST_HOME/config-vault1.hcl > $TEST_HOME/vault1.log 2>&1 &"
# sleep 1s

# cyan "Initialize vault1"
# pe "vault_1 operator init -format=json -key-shares 1 -key-threshold 1 > /tmp/vault1-key.txt"
# pe "cat /tmp/vault1-key.txt | jq -r ."
# pe "UNSEAL_KEY=$(cat /tmp/vault1-key.txt | jq -r .unseal_keys_b64[0])"
# pe "ROOT_TOKEN=$(cat /tmp/vault1-key.txt | jq -r .root_token)"
# # echo $UNSEAL_KEY
# # echo $ROOT_TOKEN

# cyan "Unseal vault1"
# pe "vault_1 operator unseal $UNSEAL_KEY"
# pe "vault_1 login $ROOT_TOKEN"

# green "Enable audit device, so you can examine logs later"
# pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"
# sleep 1s

##########################################################################################

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
cyan "Enable Transit secret engine for Auto Unseal"
pe "VAULT_ADDR=http://${VAULT1}:8200 vault secrets enable transit"

green "Create a key named 'autounseal'"
pe "vault write -f transit/keys/autounseal"

green "Create autounseal policy which permits update against
transit/encrypt/autounseal and transit/decrypt/autounseal paths"
tee /tmp/autounseal.hcl <<EOF
path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF
p

green "Create an 'autounseal' policy"
pe "vault policy write autounseal /tmp/autounseal.hcl"

green "Create a client token with autounseal policy attached and response wrap it with TTL of 3600 seconds."
pe "vault token create -policy="autounseal" -wrap-ttl=3600 -format=json | tee /tmp/unseal_token.txt"
# pe "vault token create -wrap-ttl=600 > /tmp/unseal_token.txt"
# pe "cat /tmp/unseal_token.txt"

yellow "We will pass the generated wrapping_token to vault2"
# pe "UNSEAL_TOKEN=$(grep 'token:' /tmp/unseal_token.txt | awk '{print $NF}')"
pe "UNSEAL_TOKEN=$(cat /tmp/unseal_token.txt | jq -r .wrap_info.token)"
pe "vault token lookup $UNSEAL_TOKEN"
# pe "export VAULT_ADDR=http://127.0.0.2:8200"
pe "VAULT_TOKEN=$UNSEAL_TOKEN vault unwrap | tee /tmp/wrapping_token.txt"
# pe "cat /tmp/wrapping_token.txt"
yellow "Note the token and policies."
pe "WRAP_TOKEN=$(grep 'token' /tmp/wrapping_token.txt | head -n 1 | awk '{print $NF}')"


cyan "
##########################################################################################
# CREATE CONFIGURATION FILES FOR VAULT 2, 3, 4
##########################################################################################"
echo
cyan "Create config for vault2"
yellow "For secure environments, export the token as VAULT_TOKEN env variable, instead of in seal stanza"
tee $TEST_HOME/config-vault2.hcl <<EOF
storage "raft" {
  path    = "$TEST_HOME/vault-raft/"
  node_id = "node2"
}
listener "tcp" {
  address = "${VAULT2}:8200"
  cluster_address = "${VAULT2}:8201"
  tls_disable = true
}
seal "transit" {
  address            = "http://${VAULT1}:8200"
  token              = "$WRAP_TOKEN"
  disable_renewal    = "false"
  // Key configuration
  key_name           = "autounseal"
  mount_path         = "transit/"
}
disable_mlock = true
cluster_addr = "http://${VAULT2}:8201"
EOF
p "Press Enter"
echo
echo

cyan "Create config for vault3"
echo
tee $TEST_HOME/config-vault3.hcl <<EOF
storage "raft" {
  path    = "$TEST_HOME/vault-raft2/"
  node_id = "node3"
}
listener "tcp" {
  address = "${VAULT3}:8200"
  cluster_address = "${VAULT3}:8201"
  tls_disable = true
}
seal "transit" {
  address            = "http://${VAULT1}:8200"
  token              = "$ROOT_TOKEN"
  disable_renewal    = "false"
  // Key configuration
  key_name           = "autounseal"
  mount_path         = "transit/"
}
disable_mlock = true
cluster_addr = "http://${VAULT3}:8201"
EOF
p "Press Enter"
echo

cyan "Create config for vault4"
echo
tee $TEST_HOME/config-vault4.hcl <<EOF
storage "raft" {
  path    = "$TEST_HOME/vault-raft3/"
  node_id = "node4"
}
listener "tcp" {
  address = "${VAULT4}:8200"
  cluster_address = "${VAULT4}:8201"
  tls_disable = true
}
seal "transit" {
  address            = "http://${VAULT1}:8200"
  token              = "$ROOT_TOKEN"
  disable_renewal    = "false"
  // Key configuration
  key_name           = "autounseal"
  mount_path         = "transit/"
}
disable_mlock = true
cluster_addr = "http://${VAULT4}:8201"
EOF
p "Press Enter"
echo

cyan "
##########################################################################################
# START VAULT 2, 3, 4
##########################################################################################"

pe "rm -rf $TEST_HOME/vault-raft/ $TEST_HOME/vault-raft2/ $TEST_HOME/vault-raft3/"
pe "mkdir -pm 0755 $TEST_HOME/vault-raft $TEST_HOME/vault-raft2 $TEST_HOME/vault-raft3"

pe "VAULT_API_ADDR=http://${VAULT2}:8200 vault server -log-level=trace -config $TEST_HOME/config-vault2.hcl > $TEST_HOME/vault2.log 2>&1 &"
pe "VAULT_API_ADDR=http://${VAULT3}:8200 vault server -log-level=trace -config $TEST_HOME/config-vault3.hcl > $TEST_HOME/vault3.log 2>&1 &"
pe "VAULT_API_ADDR=http://${VAULT4}:8200 vault server -log-level=trace -config $TEST_HOME/config-vault4.hcl > $TEST_HOME/vault4.log 2>&1 &"

sleep 1s

##########################################################################################
# vault2
##########################################################################################

cyan "Initialize vault2"
pe "export VAULT_ADDR=http://${VAULT2}:8200"
pe "vault operator init -format=json -recovery-shares 1 -recovery-threshold 1 > /tmp/vault2-key.txt"
# INIT_RESPONSE2=$(vault_2 operator init -format=json -key-shares 1 -key-threshold 1)

# UNSEAL_KEY2=$(echo $INIT_RESPONSE2 | jq -r .unseal_keys_b64[0])
# ROOT_TOKEN2=$(echo $INIT_RESPONSE2 | jq -r .root_token)
pe "UNSEAL_KEY2=$(cat /tmp/vault2-key.txt | jq -r .recovery_keys_b64[0])"
pe "ROOT_TOKEN2=$(cat /tmp/vault2-key.txt | jq -r .root_token)"

# echo $UNSEAL_KEY2
# echo $ROOT_TOKEN2

yellow "Pause for services to start"
sleep 10s

pe "vault login $ROOT_TOKEN2"

yellow "Check raft cluster for vault2"
pe "vault status"
pe "vault operator raft configuration -format=json | jq"
echo

cyan "Enable kv secrets"
pe "vault secrets enable -path=kv kv-v2"
pe "vault kv put kv/apikey webapp=ABB39KKPTWOR832JGNLS02"
pe "vault kv get kv/apikey"

##########################################################################################
# vault3
##########################################################################################
# echo
# green "NOTE: Vault3 not initialized until after raft join."
pe "export VAULT_ADDR=http://${VAULT3}:8200"
# pe "vault status"

cyan "Join vault3 to the raft cluster"
pe "vault operator raft join http://${VAULT2}:8200"
sleep 4s

yellow "Check raft cluster for vault3"
pe "vault operator raft configuration -format=json | jq"
echo
echo

##########################################################################################
# vault4
##########################################################################################
pe "export VAULT_ADDR=http://${VAULT4}:8200"
# pe "vault status"

cyan "Join vault4 to the raft cluster"
pe "vault operator raft join http://${VAULT2}:8200"
sleep 4s

yellow "Check raft cluster for vault4"
pe "vault operator raft configuration -format=json | jq"
yellow "You should nodes 2,3, and 4 listed out. node2 should be the leader."
echo
echo
yellow "COMPLETE"