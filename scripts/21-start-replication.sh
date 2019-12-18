#!/bin/bash
. env-replication.sh
shopt -s expand_aliases
alias dc="docker-compose"

set -e
cyan "Running: $0: Launch vault instances: vault, vault2, vault3, vault4"

tput clear
cyan "#-------------------------------------------------------------------------------
# BRING UP ENVIRONMENT
#-------------------------------------------------------------------------------\n"

green "[*] Bring up vault1 vault2 vault3 vault4."
dc up -d vault1 vault2 vault3 vault4
# dc up -d openldap postgres


# vrd > /tmp/vault.log 2>&1 &
# vrd2 > /tmp/vault2.log 2>&1 &
# vrd3 > /tmp/vault3.log 2>&1 &
# vrd4 > /tmp/vault4.log 2>&1 &

cyan "#-------------------------------------------------------------------------------
#--- START THE INSTANCES
#-------------------------------------------------------------------------------\n"

# Uses script within container to start vault. 
# VAULT_REDIRECT_ADDR=http://$(hostname):8200 vault server -log-level=trace -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200 -dev-ha -dev-transactional > vault/logs/$(hostname).out 2>&1 &


echo
cyan "#-------------------------------------------------------------------------------
#--- LICENSE THE INSTANCES
#-------------------------------------------------------------------------------\n"

green "[*] Apply license to vault"
# "You need to create your own license-vault.txt file with your license in it."
vault write /sys/license text=$(jq -r .text vault/files/licensepayload.json)
for i in {2..4}; do
vault${i} write /sys/license text=@license-vault.txt
done
# $(jq -r .text vault/files/licensepayload.json)

# This is performed in 21-start-replication.sh
# for i in {0..6..2}; do
# curl -sH "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @./vault/files/licensepayload.json http://127.0.0.1:820${i}/v1/sys/license
# curl -sH "X-Vault-Token: root" -X GET http://127.0.0.1:820${i}/v1/sys/license | jq .data.expiration_time
# done

# dc -f docker-compose-vault.yml logs | grep Unseal 
# dc logs | grep Unseal \
#   | tee >(tail -n 1 | awk '/vault-1/ {print $NF}' > /tmp/vault-1-shamir.txt) \
#   | tee >(tail -n 1 | awk '/vault-2/ {print $NF}' > /tmp/vault-2-shamir.txt) \
#   | tee >(tail -n 1 | awk '/vault-3/ {print $NF}' > /tmp/vault-3-shamir.txt) \
#   | tee >(tail -n 1 | awk '/vault-4/ {print $NF}' > /tmp/vault-4-shamir.txt) 

green "[*] Unseal vault instances"
for i in {1..4}; do
grep Unseal vault/logs/vault${i}.out | awk '{print$NF}' | tee /tmp/vault${i}-shamir.txt
done

green "[*] Enable audit logging"
vault audit enable file file_path=/tmp/audit-$(hostname).log log_raw=true
for i in {2..4}; do
vault${i} audit enable file file_path=/vault/logs/audit-vault${i}.log log_raw=true
done

cyan "#-------------------------------------------------------------------------------
# VERIFICATION SETUP
#-------------------------------------------------------------------------------\n"

cyan "#--- create admin user
#-------------------------------------------------------------------------------\n"
vault login root

green "# setup vault admin user"
vault auth enable userpass

green "#--- create vault-admin user policy"
echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault-admin -

green "# create vault user with vault-admin policy"
vault write auth/userpass/users/vault password=vault policies=vault-admin


cyan "#--- create regular user
#-------------------------------------------------------------------------------\n"

vault login root
echo '
path "supersecret/*" {
  capabilities = ["list", "read"]
}' | vault policy write user -

vault write auth/userpass/users/drtest password=drtest policies=user


cyan "#--- create some data
#-------------------------------------------------------------------------------\n"

vault secrets enable -path=supersecret generic
vault write supersecret/drtest username=harold password=baines

vault secrets enable -path=eu_gdpr kv
vault write supersecret/drtest username=harold password=baines



