#!/bin/bash
shopt -s expand_aliases
set -e
. env.sh
# Root token and
# tput clear
mkdir -p ./tmp
pkill vault || true

# run the following command manually if you need to delete previous data
#rm -r ./tmp/data

green "Vault start up data sent to /tmp/vault.log"

# vault server -dev -dev-root-token-id=$PASSWORD > ./tmp/vault.log 2>&1 &

#------------------------------------------------------------------------------
# Begin Vault Server with Config section

echo [*] Start Vault server
vault server -config ../vault.d/vault.hcl -log-level="trace" > /tmp/vault.log 2>&1 &
sleep 1
echo [*] Initialize Vault
if ! vault operator init -status > /dev/null
then
  vault operator init -key-shares=1 -key-threshold=1 -format=json | tee ./tmp/vault.init
fi
export UNSEAL_KEY=$(jq -r ".unseal_keys_b64[0]" ./tmp/vault.init)
export ROOT_TOKEN=$(jq -r ".root_token" ./tmp/vault.init)
export VAULT_TOKEN=$ROOT_TOKEN

echo [*] Unseal Vault
vault operator unseal $UNSEAL_KEY

echo [*] License Vault
curl -H "X-Vault-Token: $VAULT_TOKEN" \
-X PUT -d @../license/licensepayload.json $VAULT_ADDR/v1/sys/license

# End Vault Server with Config section
#------------------------------------------------------------------------------

green "Send Vault audit logs to /vault/logs/audit.log"
# vault audit enable file file_path=vault/logs/audit.log log_raw=true
vault audit enable file file_path=/tmp/vault-audit.log log_raw=true