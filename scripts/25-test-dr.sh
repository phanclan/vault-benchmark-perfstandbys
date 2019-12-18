. env-replication.sh
cyan "Running: $0: TEST Disaster Recovery Replication Setup"
echo
cyan "Step 3: Promote DR Secondary to Primary"

cyan "First, securely share a root token useable for Vault 3."
cyan "The secure share is allowed by using 'one time password'"

green "Generate DR operation token; used to promote DR secondary)"
pe "export VAULT_ADDR3=http://127.0.0.1:8204"
echo
green "## Validate process has NOT started"
pe "curl $VAULT_ADDR3/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq"
echo
green "Start the DR operation token generation process."
green "## Generate one time password (otp)"
yellow "DR_OTP=$(vault3 operator generate-root -dr-token -generate-otp)"
pe "DR_OTP=$(vault3 operator generate-root -dr-token -generate-otp)"

green "## Initiate DR token generation, create nonce"
yellow "NONCE=$(vault3 operator generate-root -dr-token -init -otp=${DR_OTP} | grep -i nonce | awk '{print $2}')"
pe "NONCE=$(vault3 operator generate-root -dr-token -init -otp=${DR_OTP} | grep -i nonce | awk '{print $2}')"

green "## Validate process HAS started"
pe "curl $VAULT_ADDR3/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq"


cyan "## Generate the encoded token using the unseal key from DR primary "
cyan "## as well as the nonce generated from prior execution."
cyan "##"
yellow "## Note that production clusters would normally require several executions "
yellow "## to correlate with the Shamir sharing threshold number of keys"

pe "PRIMARY_UNSEAL_KEY=$(grep "Unseal Key" /tmp/vault.log| awk '{print $NF}')"

green "## Initiate DR token generation, provide unseal keys (1 unseal key in our example)"
## THIS IS BROKEN IN 0.9.5,0.9.6 AND WILL BE FIXED IN 0.10
pe "vault3 operator generate-root -dr-token -nonce=${NONCE} ${PRIMARY_UNSEAL_KEY} > /tmp/encoded-token.txt"
pe "ENCODED_TOKEN=$(grep -i encoded /tmp/encoded-token.txt | awk '{print $3}')"

## API workaround for above:

# #--- create payload.json
# cat <<EOF > payload.json
# {
#   "key": "${PRIMARY_UNSEAL_KEY}",
#   "nonce": "${NONCE}"
# }
# EOF

# ENCODED_TOKEN=$(curl \
# --request PUT \
#     --data @payload.json \
#     $VAULT_ADDR3/v1/sys/replication/dr/secondary/generate-operation-token/update | jq .encoded_token)

## Output:
## {  
##    "nonce":"NONCE",
##    "started":true,
##   "progress":1,
##   "required":1,
##   "complete":true,
##   "encoded_token":"ENCODED_TOKEN",
##   "encoded_root_token":"",
##   "pgp_fingerprint":""
## }
##

green "Decode the generated DR operation token (Encoded Token)"
white "DR_OPERATION_TOKEN=$(vault operator generate-root -otp=${DR_OTP} -decode=${ENCODED_TOKEN})"
pe "DR_OPERATION_TOKEN=$(vault operator generate-root -otp=${DR_OTP} -decode=${ENCODED_TOKEN})"


cyan "#-------------------------------------------------------------------------------
#--- CREATE ADMIN USER
#-------------------------------------------------------------------------------\n"

pe "vault login root"
green "#--- Enable userpass secrets engine"
pe "vault auth enable userpass"

green "Create vault-admin user policy"
echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault-admin -
read

green "#--- Setup vault admin user"
pe "vault write auth/userpass/users/vault password=vault policies=vault-admin"

cyan "#-------------------------------------------------------------------------------
#--- CREATE REGULAR USER
#-------------------------------------------------------------------------------\n"

green "#--- Create regular user "

pe "vault login root"
echo '
path "supersecret/*" {
  capabilities = ["list", "read"]
}' | vault policy write user -
read
pe "vault write auth/userpass/users/drtest password=drtest policies=user"

green "write some data"
pe "vault secrets enable -path=supersecret generic"
pe "vault write supersecret/drtest username=harold password=baines"


cyan "#-------------------------------------------------------------------------------
# Perform a failover test
#-------------------------------------------------------------------------------\n"

green "#--- Auth to vault with regular user"
pe "unset VAULT_TOKEN"
pe "vault login -method=userpass username=drtest password=drtest"

green "#--- Read the supersecret/drtest values"
pe "vault read supersecret/drtest"

green "#--- Save the ephemeral token for verification"
pe "cp ~/.vault-token ~/.vault-token-DRTEST"
pe "diff ~/.vault-token ~/.vault-token-DRTEST"

cyan "#-------------------------------------------------------------------------------
# STOP PRIMARY VAULT INSTANCE (vault1)
#-------------------------------------------------------------------------------\n"

### STOP primary vault instance  - in dev mode this blows away all cluster information
### cntrl + c in the terminal windowd that you used to run vrd,  or pkill -fl 8200 
### This will kill the primary Vault cluster, but you probably want to use the Option 1 or 2 below

cyan "#-------------------------------------------------------------------------------
# OPTION 1 - DISABLE REPLICATION
#-------------------------------------------------------------------------------\n"
# cyan "# OPTION 1 - Disable replication"
# echo
green "#--- Disable replication on primary"

pe "vault login root"
pe "vault write -f /sys/replication/dr/primary/disable"
pe "vault write -f /sys/replication/performance/primary/disable"

green "#--- Verify"
pe "curl -s http://127.0.0.1:8200/v1/sys/replication/status | jq .data"

yellow "Sample Output
{
  "dr": {
    "mode": "disabled"
  },
  "performance": {
    "mode": "disabled"
  }
}"

pe "curl -s http://127.0.0.1:8202/v1/sys/replication/status | jq .data"

yellow "Sample Output
{
  "dr": {
    "mode": "disabled"
  },
  "performance": {
    "cluster_id": "a852cdcd-3a78-c892-3b56-99e85c8f0b57",
    "known_primary_cluster_addrs": [
      "https://vault1:8201"
    ],
    "last_reindex_epoch": "1573084423",
    "last_remote_wal": 2297,
    "merkle_root": "2f3bcc2bed51969fb3ecb1bb728061b7743d779a",
    "mode": "secondary",
    "primary_cluster_addr": "https://vault1:8201",
    "secondary_id": "vault2",
    "state": "stream-wals"
  }
}"

p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# OPTION 2 - DEMOTION OF REPLICATION ROLE
#-------------------------------------------------------------------------------\n"

green "# demote primary to secondary"
green "vault write -f /sys/replication/performance/primary/demote"

green "## demoting dr primary to secondary puts it in cold standby"
green "# vault write -f /sys/replication/dr/primary/demote"

p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# CHECK PERFORMANCE SECONDARY (vault2)
#-------------------------------------------------------------------------------\n"
green "# check performance secondary for access to secrets etc"
pe "vault2 login -method=userpass username=drtest password=drtest"
pe "vault2 read supersecret/drtest"

green "#--- Note that the .vault-token has changed"
pe "diff ~/.vault-token ~/.vault-token-DRTEST"

p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# PROMOTE DR SECONDARY TO PRIMARY
#-------------------------------------------------------------------------------\n"

green "#--- Promote DR secondary to primary"
pe "vault3 write -f /sys/replication/dr/secondary/promote dr_operation_token=${DR_OPERATION_TOKEN}"
sleep 2

green "#--- Make vault1 DR secondary to vault3 (primary)"
pe "vault3 login root"
pe "vault3 write /sys/replication/dr/primary/secondary-token id=vault -format=json | tee /tmp/vault3-dr-secondary-token.txt"
pe "PRIMARY_DR_TOKEN=$(jq -r '.wrap_info.token' /tmp/vault3-dr-secondary-token.txt)"
sleep 3
pe "vault login root"
pe "vault write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}"
sleep 3

green "#--- check status"
pe "vault3 read -format=json sys/replication/status | jq .data"

green "#--- let's check our token status"
pe "cp ~/.vault-token-DRTEST ~/.vault-token"

pe "vault3 read supersecret/drtest"

yellow "Sample Output:
Key             	Value
---             	-----
refresh_interval	768h0m0s
password        	baines
username        	harold"

yellow "You can use the token from vault1 on vault3. Does it work on vault2 (performance standby)?"

pe "vault2 read supersecret/drtest"

yellow "It should not work."
