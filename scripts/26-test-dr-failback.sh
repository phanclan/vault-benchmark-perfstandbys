. env-replication.sh
cyan "Running: $0: TEST Disaster Recovery Replication Setup"
echo

p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# FAILBACK - OPTION 2
#-------------------------------------------------------------------------------\n"

cyan "relevant for Vault >= 0.9.1 This scenario assumes the primary was demoted"

green "#Enable vault as DR secondary to vault3"
vault3 login root
vault3 write -f /sys/replication/dr/primary/enable
PRIMARY_DR_TOKEN=$(vault3 write -format=json /sys/replication/dr/primary/secondary-token id=vault | jq --raw-output '.wrap_info .token' )
vault login root
vault write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN}

tput clear
cyan "#-------------------------------------------------------------------------------
# PROMOTE VAULT1 INSTANCE BACK TO DISASTER RECOVERY PRIMARY
#-------------------------------------------------------------------------------\n"
green "#--- Promote original Vault instance back to disaster recovery primary"
DR_OTP=$(vault operator generate-root -dr-token -generate-otp)
NONCE=$(vault operator generate-root -dr-token -init -otp=${DR_OTP} | grep -i nonce | awk '{print $2}')
ENCODED_TOKEN=$(vault operator generate-root -dr-token -nonce=${NONCE} ${PRIMARY_UNSEAL_KEY} | grep -i encoded | awk '{print $3}'  )
DR_OPERATION_TOKEN=$(vault operator generate-root -otp=${DR_OTP} -decode=${ENCODED_TOKEN})
vault write -f /sys/replication/dr/secondary/promote dr_operation_token=${DR_OPERATION_TOKEN}
vault write -f /sys/replication/dr/primary/enable

#Demote vault 3 to secondary to return to original setup 
NEW_PRIMARY_DR_TOKEN=$(vault write -format=json /sys/replication/dr/primary/secondary-token id=vault3 | jq --raw-output '.wrap_info .token' )
vault3 write -f /sys/replication/dr/primary/demote
vault3 write /sys/replication/dr/secondary/update-primary primary_api_addr=127.0.0.1:8200 token=${NEW_PRIMARY_DR_TOKEN}

# Promote original Vault instance back to performance primary
vault write -f /sys/replication/performance/secondary/promote
vault2 write -f /sys/replication/performance/primary/demote
NEW_PRIMARY_PERF_TOKEN=$(vault write -format=json sys/replication/performance/primary/secondary-token id=vault2 \
  | jq --raw-output '.wrap_info .token' )
vault2 write /sys/replication/performance/secondary/update-primary primary_api_addr=127.0.0.1:8200 token=${NEW_PRIMARY_PERF_TOKEN}


cyan "The environment looks like the following at this step:"
echo
cat <<EOF
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
EOF
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

cyan "#--- Check status on all 3 clusters"

pe "vault read -format=json sys/replication/status | jq .data"
pe "vault2 read -format=json sys/replication/status | jq .data"
pe "vault3 read -format=json sys/replication/status | jq .data"


yellow "CLEAN UP"
pe "pkill vault"
pe "rm -f ~/.vault-token*"