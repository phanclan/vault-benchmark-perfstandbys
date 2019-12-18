. env.sh
# green 'Start Vault Server'
# pe "vault server -config=./vault/config/vault1-file-config.hcl > ./vault/logs/vault-1-stdout.txt 2>&1 &"

echo "Provide Vault Port (10101 for Vault Primary ; 10201 for Vault Secondary)"
read -rs VAULT_ADDR
  # <enter the port>
echo "Provide Consul Port (10111 for Consul dc1 ; 10211 for Consul dc2)"
read -rs CONSUL_HTTP_ADDR
  # <enter the port>
export VAULT_PORT=${VAULT_PORT:-"8200"}
export CONSUL_PORT=${CONSUL_PORT:-"8500"}
echo $VAULT_PORT
export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}
export CONSUL_HTTP_ADDR=http://127.0.0.1:${CONSUL_PORT}
echo $VAULT_ADDR
echo $CONSUL_HTTP_ADDR
p "pause"

tput clear
cyan '#------------------------------------------------------------------------------
# INITIALIZING VAULT USING SHAMIR KEYS AND UNSEALING
#------------------------------------------------------------------------------\n'

green 'Initializing Vault using Shamir Keys...'
echo
white 'COMMAND: vault operator init -key-shares=<number desired> -key-threshold=<number desired>'

# Allow Vault to fully initialize and come up in memory. Have had issues initializing w/o the pause
# sleep 1

if ! vault operator init -status > /dev/null
then
  pe 'vault operator init -key-shares=1 -key-threshold=1 | tee /tmp/vault.init'
  p "Press Enter to continue"
fi

tput clear
cyan "#------------------------------------------------------------------------------
# UNSEALING VAULT FOR OPERATIONAL USE...
#------------------------------------------------------------------------------\n"
echo
white "COMMAND: vault operator unseal <shamir key>"

# for i in {1..2}; do
#   # pe $"vault operator unseal $(grep "Key $i:" /tmp/shamir-1.txt | awk '{print $NF}')"
#   vault operator init -key-shares=1 -key-threshold=1 --format-json | tee /tmp/vault.init
#   # vault operator unseal $(grep "Key $i:" /tmp/shamir-1.txt | awk '{print $NF}')
#   # p
#   # echo "$i"
# done
jq -r ".unseal_keys_b64[0]" /tmp/vault.init | consul kv put service/vault/recovery-key -
jq -r ".root_token" /tmp/vault.init | consul kv put service/vault/root-token -


yellow 'NOTE: The above command would need to be entered with each key required by the threshold.'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
#SETTING VAULT ADDRESS AND VAULT TOKEN FOR USE
#-------------------------------------------------------------------------------\n"
echo

cyan "Configure environmental variables for CLI and API use..."
echo
green 'Set VAULT ADDR...'
# alias vault='docker-compose exec vault vault "$@"'
pe 'export VAULT_ADDR=http://127.0.0.1:8200'

green 'Setting VAULT_TOKEN variable...'
pe "export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# UPLOADING AND APPLYING LICENSE TO VAULT
#-------------------------------------------------------------------------------\n"
green 'Apply Vault license...'
echo
white 'COMMAND: curl --header "X-Vault-Token: \<vault token\>" --request PUT --data @<license file>.json <vault address>/v1/sys/license"

curl -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @./vault/files/licensepayload.json $VAULT_ADDR/v1/sys/license"'
p

curl -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @./vault/files/licensepayload.json $VAULT_ADDR/v1/sys/license
echo
echo

green 'View Vault license'
pe "vault read sys/license"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE AUDIT LOG AND DISPLAY
#-------------------------------------------------------------------------------\n"

# Optional - during development good to raw log data
green "Send Vault audit logs to ./vault/logs/audit-$(hostname)-1.log"
pe "vault audit enable file file_path=./vault/logs/audit-$(hostname)-1.log log_raw=true"
# vault audit disable file

yellow "Logs are located here:
tail -f /Users/pephan/Dropbox/code/HashiCorp/terraform-guides/infrastructure-as-code/hashistack/dev/vagrant-local/vault_essential_patterns_blog/vault/logs/audit-1.log | jq -r"
echo
p "Press enter to continue"


white "
VAULT HAS BEEN SUCCESSFULLY STARTED, INITIALIZED, AND LICENSED
--------------------------------------------------------------
Vault has been successfully initialized, unsealed and is ready for operational use.
You can begin using vault via CLI or API commands.

To access the UI, please open a browser and point to: $VAULT_ADDR"