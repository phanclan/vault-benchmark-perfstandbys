shopt -s expand_aliases
. env.sh

export VAULT_ADDR=http://$(grep vault /tmp/describe-instances.txt | awk '{print $NF}'):8200
cd ..
export CONSUL_HTTP_ADDR=$(terraform output | grep consul_ui | awk '{print $NF}')
echo $VAULT_ADDR
echo $CONSUL_HTTP_ADDR

tput clear
cyan "#-------------------------------------------------------------------------------
#--- Running: $0: Testing HR requirements
#-------------------------------------------------------------------------------\n"
unset PGUSER PGPASSWORD
white "Ensure the root token isn't being used"
pe "unset VAULT_TOKEN"

green "Log in with a memberOf overlay. Notice the path difference"
# Actually not using memberOf. Groups are mapped to this using UM.
pe "vault login -method=ldap -path=ldap-mo username=frank password=${USER_PASSWORD}"
p "Press Enter to continue"

tput clear
green "#--- Read out the dynamic DB credentials and store them as variables"
echo
green "Getting dynamic db credentials from Vault. There are more elegant ways of 
doing this, but this shows the process well"

pe "vault read -format=json db-blog/creds/mother-hr-full-1h | \
jq -r '.data | .[\"PGUSER\"] = .username | .[\"PGPASSWORD\"] = .password | del(.username, .password) | to_entries | .[] | .key + \"=\" + .value ' | tee /tmp/.temp_db_creds"
pe ". /tmp/.temp_db_creds && rm /tmp/.temp_db_creds"

green "Set the postgres environment variables to the dynamic creds, so we can run PSQL with those dynamic creds"
pe "export PGUSER=${PGUSER} PGPASSWORD=${PGPASSWORD}"
p "Press Enter to continue"

tput clear
green "Turn off globbing for the database query in an environment variable so it doesn't pick up file names instead"
pe "set -o noglob"
pe "QUERY='select email,id from hr.people;'"
pe "psql"
p "Press Enter to continue"

tput clear
green "#-------------------------------------------------------------------------------
#--- Find an existing user id and encrypt it
#-------------------------------------------------------------------------------\n"
red "WARNING! When doing this in production, it's best to schedule a maintenance window 
unless your application logic can consume both encrypted and unencrypted values"
echo
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
# -A Switches to unaligned output mode.
# -t Turn off printing of column names and result row count footers, etc. 
export PG_OPTIONS="-A -t"
pe "user_id=\$(psql)"
echo "user_id = ${user_id}"
export PG_OPTIONS=""

pe "enc_id=\$(vault write -field=ciphertext transit-blog/encrypt/hr plaintext=\$( base64 <<< \${user_id} ) )"

pe "QUERY=\"UPDATE hr.people SET id='${enc_id}' WHERE email='alice@ourcorp.com'\""
pe "psql"

# Turn off headings and aligned output
pe "QUERY=\"select email,id from hr.people\""
pe "psql"
yellow "NOTE: The id for alice is now a ciphertext!"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
#--- DECRYPT DATA FROM DATABASE
#-------------------------------------------------------------------------------\n"

green "#--- This is the process your applications will use when data is encrypted with Vault"
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
export PG_OPTIONS="-A -t"
pe "enc_user_id=\$(psql)"
echo "enc_user_id = ${enc_user_id}"
export PG_OPTIONS=""

pe "user_id=\$(vault write -field=plaintext transit-blog/decrypt/hr ciphertext=\${enc_user_id} | base64 --decode)"
pe "echo \${user_id}"

yellow "NOTE: The value is still encrypted in the database.   
It should only be decrypted by your applications when needed to be displayed"

echo
green "Confirm that database value is still encrypted."
pe "QUERY=\"select email,id from hr.people\""
pe "psql"
p "Press Enter to continue"

tput clear
red "#-------------------------------------------------------------------------------
#--- NEGATIVE TESTS - EXPECT FAILURES
#-------------------------------------------------------------------------------\n"

yellow "Try to query the engineering schema from here."
pe "QUERY=\"select * from engineering.catalog\""
pe "psql"

yellow "Can the Vault token read from other areas?"
pe "vault read db-blog/creds/mother-full-read-1h"
pe "vault kv get kv-blog/it/servers/hr/root"

yellow "If you want to re-run this demo, you should restart the database: docker kill postgres && ./1_launch_db.sh"
green "https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit"