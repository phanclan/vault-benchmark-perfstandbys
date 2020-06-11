#!/bin/bash
set -e
echo "#==> Source environment"
. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_TOKEN=$(consul kv get service/vault/root-token)
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
# green "Enter vault port:"
# export VAULT_PORT=$(read -rs VAULT_PORT)
# export VAULT_PORT=${VAULT_PORT:-10101}
# export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}

tput clear
cyan "################################################################################
# Running: $0:
#
# ENABLE/CONFIGURE THE DATABASE SECRETS ENGINE FOR DYNAMIC SECRETS
################################################################################\n"

# Have Mac activate pgAdmin 4 as part of demo
osascript -e "tell application \"pgAdmin 4\" to activate"

cyan 'In this example we are going to show how Vault can dynamically create
secrets -> a just what you need, when you need, where you need capability.
Again, the appropriate secrets engine must be enabled first.

Configuration Steps:
1. Enable the database secrets engine
2. Configure it with the database plugin and connect string
3. Create roles that can create new credentials \n'

green "Check existing secrets engines to see if database is currently enabled."
echo
white 'COMMAND: vault secrets list'
pe 'vault secrets list'

echo
green "#--- Step 1: Enable Database Secret engine."
echo
white "COMMAND: vault secrets enable database"
pe "vault secrets enable -path=${DB_PATH} database || true"
p "Press Enter to continue"

# tput clear
green "[*] Confirm what secrets engines are available for use now."
pe 'vault secrets list'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CONFIGURE THE DATABASE SECRETS ENGINE TO USE POSTGRESQL
#-------------------------------------------------------------------------------\n"

cyan "For Vault to dynamically create secrets for the database it must first
configure the database secrets engine. In this case we will utilize postgresql.

You set the engine with the required plugin and connection details..."
echo

# vault write database/config/labapp plugin_name=postgresql-database-plugin \
#     allowed_roles=\"readonly, write\" \
#     connection_url=postgresql://bunsenhoneydew:honeydew@localhost/labapp?sslmode=disable

green "#--- Step 2: Configure plugin and connection info that Vault uses to connect to database."
white 'COMMAND: vault write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="readonly, write" \
    connection_url=postgresql://{{username}}:{{password}}@localhost/labapp?sslmode=disable'
echo
cat << EOF
vault write ${DB_PATH}/config/${PGDATABASE} \\
    plugin_name=postgresql-database-plugin \\
    allowed_roles=* \\
    connection_url="postgresql://{{username}}:{{password}}@${IP_ADDRESS}:${PGPORT}/${PGDATABASE}?sslmode=disable" \\
    username="${VAULT_ADMIN_USER}" \\
    password="${VAULT_ADMIN_PW}" \\
EOF
p "Press Enter to continue"
vault write ${DB_PATH}/config/${PGDATABASE} \
    plugin_name=postgresql-database-plugin \
    allowed_roles=* \
    connection_url="postgresql://{{username}}:{{password}}@${IP_ADDRESS}:${PGPORT}/${PGDATABASE}?sslmode=disable" \
    username="${VAULT_ADMIN_USER}" \
    password="${VAULT_ADMIN_PW}"

green "Rotate the credentials for ${VAULT_ADMIN_USER} so no human has access to them anymore"
white "vault write -force ${DB_PATH}/rotate-root/${PGDATABASE}"
p "Press Enter to continue"


# tput clear
cyan "#-------------------------------------------------------------------------------
# CONFIGURE THE DATABASE ROLE THAT CONFIGURES USERS IN THE DB
#-------------------------------------------------------------------------------\n"

green "#==> STEP 3: Configure the Vault/Postgres database roles with time bound credential templates\n"
echo
yellow "There are 30s and 1h credential endpoints.  30s are great for demo'ing so you can see them expire"
echo

# Just set this here as all will likely use the same one
MAX_TTL=24h

echo
green "#--- Full read can be used by security teams to scan for credentials in any schema - 30s \n"
echo
ROLE_NAME="full-read"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
  GRANT USAGE ON SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\";
  GRANT SELECT ON ALL TABLES IN SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\";"
TTL=30s
write_db_role

echo
green "#--- Full read can be used by security teams to scan for credentials in any schema - 1h \n"
echo
TTL=1h
write_db_role

tput clear
green "#--- HR will be granted full access to their schema - 30s \n"
echo
ROLE_NAME="hr-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT USAGE ON SCHEMA hr TO \"{{name}}\";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr TO \"{{name}}\";"
TTL=30s
write_db_role

echo
green "#--- HR will be granted full access to their schema - 1h \n"
echo
TTL=1h
write_db_role

tput clear
green "#--- Engineering will be granted full access to their schema - 30s \n"
echo
green "Engineering will be granted full access to their schema"
ROLE_NAME="engineering-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT USAGE ON SCHEMA engineering TO \"{{name}}\";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA engineering TO \"{{name}}\";"
TTL=30s
write_db_role

echo
green "#--- Engineering will be granted full access to their schema - 1h \n"
echo
TTL=1h
write_db_role

tput clear
cyan "#------------------------------------------------------------------------------
# GENERATE A NEW SET OF DATABASE CREDENTIALS FOR USE VIA CLI
#------------------------------------------------------------------------------"
echo ""
cyan "Generating a new database credential is as simple as hitting the readonly role
and having Vault create the user on the fly inside the database."
echo ""
white "GENERATE COMMAND VIA CLI: vault read database/creds/readonly"
echo ""
echo "How many database users do you want to create (enter a number):"
read DBCREDS
echo ""
# cyan "Starting terminal to watch postgres..."
green "#==> Open a new terminal window and run the following:
/Users/pephan/Dropbox/code/HashiCorp/vault-benchmark-perfstandbys/vault/scripts/psqlwatch.sh
"
p "Press Enter to continue"

green "Creating database users..."
echo ""

for i in $(seq 1 $DBCREDS); do
    vault read db-blog/creds/mother-hr-full-30s
    echo ""
done

p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
#GENERATE A NEW SET OF DATABASE CREDENTIALS FOR USE VIA API
#------------------------------------------------------------------------------"
echo ""
white 'GENERATE COMMAND VIA API: curl --header "X-Vault-Token: $VAULT_TOKEN" --request GET $VAULT_ADDR/v1/database/creds/readonly | jq'
echo ""
echo ""
echo "curl --header "X-Vault-Token: $VAULT_TOKEN" --request GET $VAULT_ADDR/v1/${DB_PATH}/creds/readonly | jq"
echo ""
p
curl -H "X-Vault-Token: $VAULT_TOKEN" -X GET $VAULT_ADDR/v1/${DB_PATH}/creds/mother-engineering-full-30s | jq

echo ""
white "This concludes the dynamic secrets engine component of the demo."
p "Press any key to return to menu..."