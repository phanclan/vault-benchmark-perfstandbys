. env.sh
set -e
shopt -s expand_aliases
alias dc="docker-compose"

tput clear
cyan "#-------------------------------------------------------------------------------
# BRING UP ENVIRONMENT
#-------------------------------------------------------------------------------\n"

green "[*] Bring up cc1s1, cc1c1, and cc1c2."
dc up -d cc1s1 cc1s2 cc1s3
sleep 3
dc up -d vc1s1 vc1s2 vc1s3 
sleep 5
dc up -d vault1 openldap postgres
sleep 3

echo
green "Provide Vault Port (10101 for Vault Primary ; 10201 for Vault Secondary)"
read -rs VAULT_PORT
  # <enter the port>
green "Provide Consul Port (10111 for Consul dc1 ; 10211 for Consul dc2)"
read -rs CONSUL_PORT
  # <enter the port>
sleep 2

export VAULT_PORT=${VAULT_PORT:-"10101"}
export CONSUL_PORT=${CONSUL_PORT:-"10111"}
echo $VAULT_PORT
export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT:-"10101"}
export CONSUL_HTTP_ADDR=http://127.0.0.1:${CONSUL_PORT:-"10111"}
# green 'Start Vault Server'
# pe "vault server -config=./vault/config/vault1-file-config.hcl > ./vault/logs/vault-1-stdout.txt 2>&1 &"

tput clear
cyan '#-------------------------------------------------------------------------------
# INITIALIZING VAULT USING SHAMIR KEYS AND UNSEALING
#-------------------------------------------------------------------------------\n'

green '#--- Initializing Vault using Shamir Keys...'
echo
white 'COMMAND: vault operator init -key-shares=<number desired> -key-threshold=<number desired>'
p "Press Enter to continue"

# Allow Vault to fully initialize and come up in memory. Have had issues initializing w/o the pause
# sleep 1
echo $?
while ! vault operator init -status > /dev/null
do
  curl -sX PUT -d @./vault/config/vc_init_payload.json \
      http://127.0.0.1:${VAULT_PORT}/v1/sys/init | \
      jq | tee ./vault/config/tmp/${VAULT_PORT}.init
  sleep 3
done


p "Press Enter to continue"

green "#--- Place recovery keys and root token into consul."
for i in {0..1}; do
  jq -r ".keys[$i]" vault/config/tmp/${VAULT_PORT}.init | consul kv put service/vault/recovery-key-$i -
done
jq -r ".root_token" vault/config/tmp/${VAULT_PORT}.init | consul kv put service/vault/root-token -

p "Press Enter to continue"


tput clear
green "#------------------------------------------------------------------------------
# UNSEALING VAULT FOR OPERATIONAL USE...
#------------------------------------------------------------------------------\n"
echo
white "COMMAND: vault operator unseal <shamir key>"
echo
yellow 'NOTE: The above command would need to be entered with each key required by the threshold.'
p "Press Enter to continue"

green "#--- Unseal ${VAULT_PORT}"
for i in {0..1}; do
  curl -sX PUT -d '{"key": "'"$(consul kv get service/vault/recovery-key-$i)"'"}' \
    http://127.0.0.1:${VAULT_PORT}/v1/sys/unseal | jq
done
green "#--- Unseal 10102; using ${VAULT_PORT} init data"
for i in {0..1}; do
  curl -s -X PUT -d '{"key": "'"$(jq -r .keys[$i] vault/config/tmp/${VAULT_PORT}.init)"'"}' \
    http://127.0.0.1:$((${VAULT_PORT} + 1))/v1/sys/unseal | jq
done
green "#--- Unseal 10103; using ${VAULT_PORT} init data"
for i in {0..1}; do
  curl -s -X PUT -d '{"key": "'"$(jq -r .keys[$i] vault/config/tmp/${VAULT_PORT}.init)"'"}' \
    http://127.0.0.1:$((${VAULT_PORT} + 2))/v1/sys/unseal | jq
done

p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# SETTING VAULT ADDRESS AND VAULT TOKEN FOR USE
#-------------------------------------------------------------------------------\n"

cyan "Configure environmental variables for CLI and API use..."
echo
green 'Set VAULT ADDR...'
# alias vault='docker-compose exec vault vault "$@"'
pe "export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}"

green 'Setting VAULT_TOKEN variable...'
# pe "export VAULT_TOKEN=$(jq -r .root_token vault/config/tmp/${VAULT_PORT}.init)"
pe "export VAULT_TOKEN=$(consul kv get service/vault/root-token)"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# UPLOADING AND APPLYING LICENSE TO VAULT
#-------------------------------------------------------------------------------\n"
green 'Apply Vault license...'
echo
white 'COMMAND: curl --header "X-Vault-Token: \<vault token\>" --request PUT --data @<license file>.json <vault address>/v1/sys/license"

curl -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @./vault/files/licensepayload.json $VAULT_ADDR/v1/sys/license"'
# For cluster; do silently
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @./vault/files/licensepayload.json $VAULT_ADDR/v1/sys/license

green 'View Vault license'
pe "vault read sys/license"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE AUDIT LOG AND DISPLAY
#-------------------------------------------------------------------------------\n"

green "Send Vault audit logs to ./vault/logs/audit-1.log"
set +e
pe "vault audit enable file file_path=./vault/logs/audit-${VAULT_PORT}.log"
# pe "vault audit enable file file_path=/tmp/audit-${VAULT_PORT}.log log_raw=true"
set -e

yellow "Logs are located here:"
# tail -f /Users/pephan/Dropbox/code/HashiCorp/terraform-guides/infrastructure-as-code/hashistack/dev/vagrant-local/vault_essential_patterns_blog/vault/logs/audit-1.log | jq -r
white "tail -f ./vault/logs/audit-${VAULT_PORT}.log | jq "
echo
p "Press enter to continue"


white "
VAULT HAS BEEN SUCCESSFULLY STARTED, INITIALIZED, AND LICENSED
--------------------------------------------------------------
Vault has been successfully initialized, unsealed and is ready for operational use.
You can begin using vault via CLI or API commands.

To access the UI, please open a browser and point to: $VAULT_ADDR

Run the following commands:
export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
export CONSUL_HTTP_ADDR=http://127.0.0.1:${CONSUL_PORT}"


### To be completed !!!!!
#https://github.com/hashicorp/vault-snippets/blob/master/vault-replication/disaster-recovery.md