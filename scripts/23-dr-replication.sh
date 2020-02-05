. env-replication.sh
shopt -s expand_aliases
alias dc="docker-compose"

echo
cyan "#-------------------------------------------------------------------------------
# Running: $0: REPLICATION - PERFORMANCE AND DR
#-------------------------------------------------------------------------------\n"

cyan "We will run three Vault processes to validate Vault replication capabilities and operations.

The first Vault (vault1) will be the primary for both Performance and DR replications.
The second Vault (vault2) will be the secondary for performance.
The third Vault (vault3) will be the secondary for DR.

More information on performance and DR replication can be found
https://www.vaultproject.io/docs/enterprise/replication/index.html

NOTE: Requires Vault Enterprise binary in your local OS flavor. "
p "Press Enter to continue..."


cyan "#-------------------------------------------------------------------------------
#--- SETUP COMMANDS
#-------------------------------------------------------------------------------\n"

cyan "Setup reusable commands so that everthing can be executed from one location

Before DR replication, the Secondary DR cluster will have its own Root token and Unseal Key.
When DR replication is enabled, it will adopt the Primary's cluster Root Token and Unseal key"

################### This is from vault-snippets, but sticking with vault-guides
# export VAULT_PRIMARY_ADDR=http://127.0.0.1:10101
# export VAULT_SECONDARY_ADDR=http://127.0.0.1:10201

# export VAULT_SECONDARY_CLUSTER_ADDR=http://127.0.0.1:8201
# export VAULT_PRIMARY_CLUSTER_ADDR=http://127.0.0.1:8201


# vault_primary () {
# VAULT_ADDR=${VAULT_PRIMARY_ADDR} vault $@
# }

# vault_secondary () {
#   VAULT_ADDR=${VAULT_SECONDARY_ADDR} vault $@
# }

# green "Save Primary and DR Tokens"

# read -rs ROOT_TOKEN
#  <enter the token>
#  export VAULT_TOKEN=${ROOT_TOKEN}

# read -rs DR_ROOT_TOKEN
#  <enter the token>
##################################################################################

# export ROOT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export CONSUL_HTTP_ADDR=http://127.0.0.1:10111
# export ROOT_TOKEN=$(consul kv get service/vault/root-token)
# export CONSUL_HTTP_ADDR=http://127.0.0.1:10211
# export DR_ROOT_TOKEN=$(consul kv get service/vault/root-token)


tput clear
cyan "#-------------------------------------------------------------------------------
# MODEL IS AS FOLLOWS
#-------------------------------------------------------------------------------\n"

green "#--- Model is as follows"
white "
+---------------------------------+                    +------------------------------------+
| vault port:8200                 |                    | vault2 port: 8202                  |
| Performance primary replication |    +----------->   | Performance secondary replication  |
| DR primary replication          |                    | (vault -> vault2)                  |
|                                 |                    |                                    |
+---------------------------------+                    +------------------------------------+

               +
               |
               v

+---------------------------------+
| vault3 port:8204                |
| DR secondary replication        |
| (vault -> vault3)               |
|                                 |
+---------------------------------+
"
p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
#--- SETUP PERFORMANCE REPLICATION (vault1 -> vault2)
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------\n"

echo
cyan "#-------------------------------------------------------------------------------
# Enable Performance Primary Replication
#-------------------------------------------------------------------------------\n"

  green "#--- Enable Performance Primary Replication"
  vault login root
  pe "vault write -f sys/replication/performance/primary/enable"
  sleep 3

  green "#--- Fetch a secondary bootstrap token"
  vault write -format=json sys/replication/performance/primary/secondary-token \
      id=vault2 | tee /tmp/perf-secondary-token.txt
  PRIMARY_PERF_TOKEN=$(jq -r '.wrap_info.token' /tmp/perf-secondary-token.txt)
  echo $PRIMARY_PERF_TOKEN
  # PRIMARY_PERF_TOKEN=$(vault write -format=json sys/replication/performance/primary/secondary-token id=vault2 \
    # | jq --raw-output '.wrap_info .token' )
  p "Press Enter to continue..."


echo
tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE PR SECONDARY CLUSTER (vault2)
#-------------------------------------------------------------------------------\n"

  green "#--- From secondary node, activate a secondary using the fetched token."
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
    p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
#--- SETUP DR REPLICATION (vault -> vault3)
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------\n"


tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE DR REPLICATION ON PRIMARY CLUSTER (vault1)
#-------------------------------------------------------------------------------\n"

  green "#--- Enable DR replication on the primary (vault)"
  # export VAULT_TOKEN=${ROOT_TOKEN}
  # pe "vault login ${ROOT_TOKEN}"
  vault login root
  pe "vault write -f sys/replication/dr/primary/enable"
  sleep 3

  green "#--- Create a secondary Token to Link a Secondary Cluster"
  pe "vault write sys/replication/dr/primary/secondary-token id="vault3" -format=json | tee /tmp/dr-secondary-token.txt"
  pe "PRIMARY_DR_TOKEN=$(jq -r '.wrap_info .token' /tmp/dr-secondary-token.txt)"
  pe "echo $PRIMARY_DR_TOKEN"

  yellow "We need the wrapping token to enable the DR secondary cluster."


cyan "#-------------------------------------------------------------------------------
# Step 2: ENABLE DR REPLICATION ON SECONDARY CLUSTER (vault3)
#-------------------------------------------------------------------------------\n"

  green "Enable DR replication on the secondary cluster."
  vault3 login root
  pe "vault3 write sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}"
  sleep 3

  echo
  red "Warning: This will immediately clear all data in the secondary cluster."

cyan "#-------------------------------------------------------------------------------
# VERIFY
#-------------------------------------------------------------------------------\n"

  echo
  green "Check status from Primary DR cluster (vault)"
  pe "curl http://127.0.0.1:8200/v1/sys/replication/status | jq .data"
  yellow'
  Parameters to check on the primary:
  - cluster_id: Unique ID for this set of replicas. This value must match on the Primary and Secondary.
  - known_secondaries: List of the IDs of all non-revoked secondary activation tokens created by this Primary. The ID will be listed regardless of whether or not the token was used to activate an actual secondary cluster.
  - mode: This should be "primary".
  - primary_cluster_addr: If you set a primary_cluster_addr when enabling replication, it will appear here. If you did not explicitly set this, this field will be blank on the primary.
  As such, a blank field here can be completely normal.
  - state: This value should be running on the primary. If the value is idle, it indicates an issue and needs to be investigated.'

  green "Check status from Secondary DR cluster (vault3)"
  pe "curl http://127.0.0.1:8202/v1/sys/replication/status | jq .data"

  yellow "
  On the Secondary:
    - cluster_id: Unique ID for this set of replicas. This value must match on the Primary and Secondary.
      known_primary_cluster_addrs: List of cluster_addr values from each of the nodes in the Primary's cluster. This list is updated approximately every 5 seconds and is used by the Secondary to know how to communicate with the Primary in the event of a Primary node's active leader changing.
    - last_remote_wal: The last WAL index that the secondary received from the primary via WAL streaming.
      merkle_root: A snapshot in time of the merkle tree's root hash. The merkle_root changes on every update to storage.
    - mode: This should be 'secondary'.
    - primary_cluster_addr: This records the very first address that the secondary uses to communicate with the Primary after replication is enabled. It may not reflect the current address being used (see known_primary_cluster_addrs).
    - secondary_id: The ID of the secondary activation token used to enable replication on this secondary cluster.
    - state:
        - stream-wals: Indicates normal streaming. This is the value you want to see.
        - merkle-diff: Indicates that the cluster is determining the sync status to see if a merkle sync is required in order for the secondary to catch up to the primary.
        - merkle-sync: Indicates that the cluster is syncing. This happens when the secondary is too far behind the primary to use the normal stream-wals state for catching up. This state is blocking.
        - idle: Indicates an issue. You need to investigate."


cyan "#-------------------------------------------------------------------------------
# OPTIONAL - 4TH CLUSTER DR (vault4) FOR PERFORMANCE SECONDARY (vault2)
#-------------------------------------------------------------------------------\n"

  green "setup DR replication (vault2 -> vault4)"

  green "Enable DR replication primary (vault2)"
  vault2 login root
  vault2 write -f sys/replication/dr/primary/enable
  PRIMARY_DR_TOKEN=$(vault2 write -format=json /sys/replication/dr/primary/secondary-token id=vault4 | jq --raw-output '.wrap_info .token' )
  echo $PRIMARY_DR_TOKEN

  green "#--- Enable DR replication secondary (vault4)"
  vault4 login root
  vault4 write sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}

  green "#--- Validation:"
  green "#--- Check replication status"
  pe "vault2 read sys/replication/dr/status"
  echo

  green "#--- Check replication status"
  pe "vault4 read sys/replication/dr/status"
  echo

  yellow "NOTE: The cluster ids are the same on both clusters.
  Pay attention to mode, primary cluster address, and known_secondaries list \n"


tput clear
cyan "#-------------------------------------------------------------------------------
# VERIFICATION - PERFORMANCE REPLICATION AND MOUNT FILTER
#-------------------------------------------------------------------------------\n"

green "#--- Create a mount filter to blacklist EU_GDPR_data."
white 'vault write sys/replication/performance/primary/mount-filter/<secondary>  \
       mode="blacklist" paths="<paths>"'
vault write sys/replication/performance/primary/mount-filter/vault2  \
       mode="blacklist" paths="eu_gdpr/"

# http://localhost:8200/ui/vault/replication/performance/secondaries
# Go to Mount Filter config. Select whitelist. Select all mounts except GDPR.


tput clear
cyan "#-------------------------------------------------------------------------------
# Step 3: Demote Primary Cluster as Secondary Before Making DR CLuster Primary
#-------------------------------------------------------------------------------\n"

red "Always take care to never have two primary clusters running. You may lose data"

green "#--- FIRST Demote primary vault instance.
# You CANNOT Have Two primary Instances at once!!!"

vault login root
vault write -f /sys/replication/dr/primary/demote
# curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X POST ${VAULT_PRIMARY_ADDR}/v1/sys/replication/dr/primary/demote

green "Check replication status on Cluster 1"
pe "vault read -format=json sys/replication/dr/status"

yellow "Mode should be secondary. State should be idle."

green "#--- Demoting DR Primary to Secondary puts it in cold standby"
vault write -f /sys/replication/dr/primary/demote



cyan "#-------------------------------------------------------------------------------
# Step 4: Promote DR Secondary (vault3) to Primary
#-------------------------------------------------------------------------------\n"

cyan "To accomplish this you need a DR Operation Token on the DR Cluster
to perform any operations

NOTE: A DR cluster cannot accept any external transactions normally
Can verify by going to DR Secondary (vault3): http://localhost:8204
"


cyan "#-------------------------------------------------------------------------------
# GENERATE DR OPERATION TOKEN
#-------------------------------------------------------------------------------\n"

  green "#--- Validate process hasn't started yet on vault3"
  curl -s http://127.0.0.1:8204/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq .started

  green "#--- 1. Generate One Time Password (OTP). Needed to Generate DR token"
  DR_OTP=$(vault3 operator generate-root -dr-token -generate-otp)
  echo $DR_OTP

    # green "Alternatively you can also"
    # white "vault3 operator generate-root -dr-token -init"

  green "#--- 2. Initiate DR token generation. Create nonce."
  green "Get NONCE to give to all your UNSEAL KEY holders"
  NONCE=$(vault3 operator generate-root -dr-token -init -otp=${DR_OTP} | grep Nonce | awk '{print $2}')
  echo ${NONCE}

    # green "To cancel attempt at any time"
    # echo
    # white "vault3 delete /sys/replication/dr/secondary/generate-operation-token/attempt"

  green "#--- Make sure process has started"
  curl -s http://127.0.0.1:8204/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq .started


  cyan "#-------------------------------------------------------------------------------
  # 3. Get Your ENCODED TOKEN that Will be Combined with OTP to Produce DR operation Token
  #-------------------------------------------------------------------------------\n"

  green "Provide UNSEAL SEAL Keys one at a time until you Get the ENCODED TOKEN at last attempt."
  echo
  yellow "The Encoded Token will Only be produced upon last UNSEAL Key entered"

        # Repeat for each UNSEAL KEY
        # If you have 3 UNSEAL KEYS as your UNSEAL threashold you can do this
        # Alternatively create a for loop

        # read -rs UNSEAL_KEY1
        # <enter the unseal key>

        # read -rs UNSEAL_KEY2
        # <enter the unseal key 2>

        # read -rs UNSEAL_KEY3
        # <enter the unseal key 3>

  # /tmp/vault1-shamir.txt created in 21-start-replication.sh
  PRIMARY_UNSEAL_KEY=$(cat /tmp/vault1-shamir.txt)

  ENCODED_TOKEN=$(vault3 operator generate-root --format=json -dr-token -nonce=${NONCE} ${PRIMARY_UNSEAL_KEY} | jq -r .encoded_token)
  echo ${ENCODED_TOKEN}
  # for i in UNSEAL_KEY1 UNSEAL_KEY2 UNSEAL_KEY3 ; do
  # ENCODED_TOKEN=$(curl  --header "X-Vault-Token: ${VAULT_TOKEN}" --request PUT --data '{"key":"'"${i}"'", "nonce":"'"${NONCE}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/update | jq  --raw-output '.encoded_token')
  #done

  #--- 4. Generate DR TOKEN
  green "Decode the generated DR operation token (Encoded Token)"
  DR_OPERATION_TOKEN=$(vault3 operator generate-root -dr-token -otp=${DR_OTP} -decode=${ENCODED_TOKEN})
  echo ${DR_OPERATION_TOKEN}

  echo
  yellow "NOTE: The DR_PROMOTE_TOKEN must begin with a 's.'.
  If it returns anything else, repeat steps to generate it again"

#--- END GENERATE DR TOKEN
#-------------------------------------------------------------------------------

#--- 5. Promote vault.secondary DR Cluster to PRIMARY

curl --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"dr_operation_token":"'"${DR_PROMOTE_TOKEN}"'",  "primary_cluster_addr":"'"${VAULT_SECONDARY_CLUSTER_ADDR}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/promote

# check status
vault_secondary read -format=json sys/replication/dr/status

green "Alternative command"
echo
white '#vault_secondary write -f /sys/replication/dr/secondary/promote dr_operation_token="${DR_PROMOTE_TOKEN}" primary_cluster_addr="${VAULT_SECONDARY_ADDR}"'



# cyan "#-------------------------------------------------------------------------------
# # VERIFICATION SETUP
# #-------------------------------------------------------------------------------\n"

# cyan "#--- create admin user
# #-------------------------------------------------------------------------------\n"
# vault login root

# green "# setup vault admin user"
# vault auth enable userpass

# green "#--- create vault-admin user policy"
# echo '
# path "*" {
#     capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }' | vault policy write vault-admin -

# green "# create vault user with vault-admin policy"
# vault write auth/userpass/users/vault password=vault policies=vault-admin


# cyan "#--- create regular user
# #-------------------------------------------------------------------------------\n"

# vault login root
# echo '
# path "supersecret/*" {
#   capabilities = ["list", "read"]
# }' | vault policy write user -

# vault write auth/userpass/users/drtest password=drtest policies=user


# cyan "#--- create some data
# #-------------------------------------------------------------------------------\n"

# vault secrets enable -path=supersecret generic
# vault write supersecret/drtest username=harold password=baines

# vault secrets enable -path=eu_gpdr kv
# vault write supersecret/drtest username=harold password=baines


cyan "#--- Perform a failover test
#-------------------------------------------------------------------------------\n"

# auth to vault with regular user
vault login -method=userpass username=drtest password=drtest
vault read supersecret/drtest

# save the ephemeral token for verification
cp ~/.vault-token ~/.vault-token-DRTEST
diff ~/.vault-token ~/.vault-token-DRTEST

### STOP primary vault instance  - in dev mode this blows away all cluster information
### cntrl + c in the terminal windowd that you used to run vrd,  or pkill -fl 8200
### This will kill the primary Vault cluster, but you probably want to use the Option 1 or 2 below

# OPTION 1 - Disable replication
# disable replication on primary
vault login root
vault write -f /sys/replication/dr/primary/disable
vault write -f /sys/replication/performance/primary/disable

# Response
curl http://127.0.0.1:8200/v1/sys/replication/status | jq
# Response
{
   ...
   "data":{
      "dr":{
         "mode":"disabled"
      },
      "performance":{
         "mode":"disabled"
      }
   },
   ...
}

curl     http://127.0.0.1:8202/v1/sys/replication/status | jq
# Response:
{
   ...
   "data":{
      "dr":{
         "mode":"disabled"
      },
      "performance":{
         "cluster_id":"b0e7cfb8-d453-0919-48b2-9c2f33bdfee7",
         "known_primary_cluster_addrs":[
            "https://127.0.0.1:8201"
         ],
         "last_remote_wal":390,
         "last_wal":695,
         "merkle_root":"c0c2622f5960fce19420a0657f6b545dbe81fb7f",
         "mode":"secondary",
         "primary_cluster_addr":"https://127.0.0.1:8201",
         "secondary_id":"vault2",
         "state":"stream-wals"
      }
   },
   ...
}

cyan "#-------------------------------------------------------------------------------
# OPTION 2 - DEMOTION OF REPLICATION ROLE
#-------------------------------------------------------------------------------\n"

# Demote Performance primary to secondary
vault login root
vault write -f /sys/replication/performance/primary/demote
sleep 3

## Demote DR primary to secondary. puts vault1 in cold standby
vault write -f /sys/replication/dr/primary/demote

# check performance secondary for access to secrets etc
vault2 login -method=userpass username=drtest password=drtest
vault2 read supersecret/drtest

# note that the .vault-token has changed
diff ~/.vault-token ~/.vault-token-DRTEST

########## STOP HERE at look at 25-test-dr.sh

cyan "#-------------------------------------------------------------------------------
## Promote DR secondary to primary
#-------------------------------------------------------------------------------\n"

  vault3 write /sys/replication/dr/secondary/promote dr_operation_token=${DR_OPERATION_TOKEN}

  ##--- Make vault1 DR secondary to vault3 (primary)
  vault3 login root
  PRIMARY_DR_TOKEN=$(vault3 write -format=json /sys/replication/dr/primary/secondary-token id=vault1 | jq -r '.wrap_info .token' )
  echo $PRIMARY_DR_TOKEN

  vault login root
  vault write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}

  # check status
  vault3 read -format=json sys/replication/status | jq .data

  # let's check our token status
  cp ~/.vault-token-DRTEST ~/.vault-token
  vault3 read supersecret/drtest

  # vault3 read supersecret/drtest
    ## Key             	Value
    ## ---             	-----
    ## refresh_interval	768h0m0s
    ## password        	baines
    ## username        	harold

    ## SUCCESS!


cyan "#-------------------------------------------------------------------------------
# The environment looks like the following at this step:
#-------------------------------------------------------------------------------\n"

  white "
  +---------------------------------+                    +------------------------------------+
  | vault port:8200                 |                    | vault2 port:8202                   |
  | Replication disabled            |                    | Performance secondary replication  |
  | (or demoted)                    |                    | vault3 --> vault2                  |
  |                                 |                    |                                    |
  +---------------------------------+                    +------------------------------------+

                                                                            ^
                                                                            |
                                                                            |
                                                                            |
  +---------------------------------+                                       |
  | vault3 port:8204                |                                       |
  | DR primary replication          |  +------------------------------------+
  | Performance primary replication |
  | vault3 --> vault2               |
  +---------------------------------+
  "


cyan "#-------------------------------------------------------------------------------
# FAILBACK - Option 1 - relevant for Vault 0.8-0.9
#-------------------------------------------------------------------------------\n"

  Note that this is not an ideal situation today,
  as we must first sync DR replication set back to vault,
  then perform another failover such that vault is the perf primary/dr primary.

  # Disable replication on vault (if not already done)
  vault write -f /sys/replication/dr/primary/disable
  vault write -f /sys/replication/performance/primary/disable

  # enable vault as DR secondary to vault3
  vault3 login root
  vault3 write -f /sys/replication/dr/primary/enable
  PRIMARY_DR_TOKEN=$(vault3 write -format=json /sys/replication/dr/primary/secondary-token id=vault | jq --raw-output '.wrap_info .token' )
  sleep 10
  vault login root
  vault write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}
  sleep 10


cyan "#-------------------------------------------------------------------------------
# FAILBACK - Option 2 - relevant for Vault >= 0.9.1
#-------------------------------------------------------------------------------\n"

This scenario assumes the primary was demoted

#Enable vault as DR secondary to vault3
vault3 login root
vault3 write -f /sys/replication/dr/primary/enable
PRIMARY_DR_TOKEN=$(vault3 write -format=json /sys/replication/dr/primary/secondary-token id=vault1 | jq -r '.wrap_info.token')
vault login root
vault write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}

# Promote original Vault instance back to disaster recovery primary
DR_OTP=$(vault operator generate-root -dr-token -generate-otp)
NONCE=$(vault operator generate-root -dr-token -init -otp=${DR_OTP} | grep -i nonce | awk '{print $2}')
ENCODED_TOKEN=$(vault operator generate-root -dr-token -nonce=${NONCE} ${PRIMARY_UNSEAL_KEY} | grep -i encoded | awk '{print $3}'  )
DR_OPERATION_TOKEN=$(vault operator generate-root -dr-token -otp=${DR_OTP} -decode=${ENCODED_TOKEN})
vault write -f /sys/replication/dr/secondary/promote dr_operation_token=${DR_OPERATION_TOKEN}
vault write -f /sys/replication/dr/primary/enable


#Demote vault 3 to secondary to return to original setup
NEW_PRIMARY_DR_TOKEN=$(vault write -format=json /sys/replication/dr/primary/secondary-token id=vault3 | jq --raw-output '.wrap_info .token' )
echo $NEW_PRIMARY_DR_TOKEN
vault3 write -f /sys/replication/dr/primary/demote


#########################################################################################################
#

DR_OTP=$(vault3 operator generate-root -dr-token -generate-otp)
echo $DR_OTP
NONCE=$(vault3 operator generate-root -dr-token -init -otp=${DR_OTP} | grep -i nonce | awk '{print $2}')
echo $NONCE
ENCODED_TOKEN=$(vault3 operator generate-root -dr-token -nonce=${NONCE} ${PRIMARY_UNSEAL_KEY} | grep -i encoded | awk '{print $3}'  )
echo $ENCODED_TOKEN
DR_OPERATION_TOKEN=$(vault3 operator generate-root -dr-token -otp=${DR_OTP} -decode=${ENCODED_TOKEN})
echo $DR_OPERATION_TOKEN
# curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X POST -d '{"dr_operation_token":"'"${DR_OPERATION_TOKEN}"'", "token":"'"${NEW_PRIMARY_DR_TOKEN}"'", "primary_adi_addr":"'"http://vault1:8200"'"}' http://127.0.0.1:8204/v1/sys/replication/dr/secondary/update-primary

#
#########################################################################################################

vault3 write -f /sys/replication/dr/secondary/update-primary dr_operation_token=${DR_OPERATION_TOKEN} token=${NEW_PRIMARY_DR_TOKEN} primary_api_addr=vault1:8200
#vault3 write /sys/replication/dr/secondary/update-primary primary_api_addr=vault1:8200 token=${NEW_PRIMARY_DR_TOKEN}

# Promote original Vault instance back to performance primary
vault write -f /sys/replication/performance/secondary/promote
vault2 write -f /sys/replication/performance/primary/demote
NEW_PRIMARY_PERF_TOKEN=$(vault write -format=json sys/replication/performance/primary/secondary-token id=vault2 \
  | jq --raw-output '.wrap_info .token' )
vault2 write /sys/replication/performance/secondary/update-primary primary_api_addr=127.0.0.1:8200 token=${NEW_PRIMARY_PERF_TOKEN}


cyan "#-------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------\n"
The environment looks like the following at this step:

+---------------------------------+                    +------------------------------------+
| vault                           |                    | vault2 port: 8202.                 |
| DR secondary replication        | +-------------->   | Performance secondary replication  |
| vault3->vault                   |                    | vault3 --> vault2                  |
|                                 |                    |                                    |
+---------------------------------+                    +------------------------------------+

              ^
              |
              |
              +
+---------------------------------+
| vault3 port:8204                |
| DR primary replication          |
| Performance primary replication |
| vault3 --> vault2               |
+---------------------------------+

# now we fail vault3 and enable vault as the primary
vault3 write -f /sys/replication/dr/primary/disable
vault3 write -f /sys/replication/performance/primary/disable

# now setup vault as DR primary to vault3
vault login root
vault write -f /sys/replication/dr/secondary/promote key=<<PASTE KEY HERE FROM VAULT here>>
vault write -f /sys/replication/dr/primary/disable
vault write -f /sys/replication/dr/primary/enable
PRIMARY_DR_TOKEN=$(vault write -format=json /sys/replication/dr/primary/secondary-token id=vault3 | jq --raw-output '.wrap_info .token' )
sleep 10
vault3 login root
vault3 write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}
sleep 10

check status on all 3

vault read -format=json sys/replication/status | jq
vault2 read -format=json sys/replication/status | jq
vault3 read -format=json sys/replication/status | jq

Clean up

# CTRL-C any running vrd sessions
rm -f ~/.vault-token*




  # Here is the command to Disable replication.
  # vault_primary write -f /sys/replication/dr/primary/disable
