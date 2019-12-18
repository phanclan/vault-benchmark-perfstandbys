cd ./scripts
. env.sh
cd -
set -e
shopt -s expand_aliases
alias dc="docker-compose"

# export CONSUL_HTTP_ADDR=http://127.0.0.1:10111
# export VAULT_TOKEN=$(consul kv get service/vault/root-token)
# pe "echo $VAULT_TOKEN"
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
# export VAULT_PORT=${VAULT_PORT:-10101}
# export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}
aws --region us-west-2 \
ec2 describe-instances --filter Name=tag-key,Values=aws:autoscaling:groupName \
--query 'Reservations[*].Instances[*].{Instance:InstanceId,AZ:Placement.AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value,PIP:PublicIpAddress}' \
--output text | grep pphan | grep -iv "NONE" | tee /tmp/describe-instances.txt

export VAULT_ADDR=http://$(grep vault /tmp/describe-instances.txt | awk '{print $NF}'):8200
cd ..
export CONSUL_HTTP_ADDR=$(terraform output | grep consul_ui | awk '{print $NF}')
echo $VAULT_ADDR
echo $CONSUL_HTTP_ADDR
p

export LDAP_HOST=openldap
p

#-------------------------------------------------------------------------------

echo '#------------------------------------------------------------------------------
# INITIALIZING VAULT USING SHAMIR KEYS AND UNSEALING
#------------------------------------------------------------------------------\n'
# Allow Vault to fully initialize and come up in memory. Have had issues initializing w/o the pause
# sleep 1

if ! vault operator init -status > /dev/null
then
  vault operator init -key-shares=1 -key-threshold=1 -format=json | tee /tmp/vault.init
  p "Press Enter to continue"
fi

echo "#------------------------------------------------------------------------------
# UNSEALING VAULT FOR OPERATIONAL USE...
#------------------------------------------------------------------------------\n"
jq -r ".unseal_keys_b64[0]" /tmp/vault.init | consul kv put service/vault/recovery-key -
jq -r ".root_token" /tmp/vault.init | consul kv put service/vault/root-token -
curl -X PUT -d '{"key": "'"$(consul kv get service/vault/recovery-key)"'"}' \
    ${VAULT_ADDR}/v1/sys/unseal
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
curl -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @../license/licensepayload.json $VAULT_ADDR/v1/sys/license

cyan "#-------------------------------------------------------------------------------
# CREATE AUDIT LOG AND DISPLAY
#-------------------------------------------------------------------------------\n"
set +e
vault audit enable file file_path=./tmp/audit-1.log log_raw=true
set -e

#-------------------------------------------------------------------------------

cyan "#-------------------------------------------------------------------------------
#  CREATE ADMIN POLICY AND USER
#-------------------------------------------------------------------------------\n"

green "#--- Admin Policies"
vault policy write admin ./vault/policies/admin-policy.hcl

green "#--- Create admin user and store in consul"
vault token create -policy=admin -field=token | consul kv put service/vault/admin-token -

# tput clear
cyan "#-------------------------------------------------------------------------------
#  3_enable_kv.sh - ENABLE STATIC SECRETS
#-------------------------------------------------------------------------------\n"
green "#--- Enable a KV V2 Secret engine at the path 'labsecrets' and kv-blog"
set +e
vault secrets enable -path=labsecrets -version=2 kv > /dev/null 2>&1
vault secrets enable -path=kv-blog -version=2 kv > /dev/null 2>&1
set -e
green '#--- CLI: Create a new secret with a "key of apikey" and 
"value of master-api-key-111111" within the "labsecrets" path:'
vault kv put labsecrets/apikeys/googlemain apikey=master-api-key-111111
green "#--- API: Create a new secret called 'gvoiceapikey' with a value of 'PassTheHash!:'"
curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{ "data": { "gvoiceapikey": "PassTheHash!" } }' \
    ${VAULT_ADDR}/v1/labsecrets/data/apikeys/googlevoice | jq 
green '#--- CLI: POST SECRET: MULTIPLE FIELDS'
vault kv put labsecrets/webapp username="beaker" password="meepmeepmeep"
green "#--- CLI: LOAD SECRET VIA FILE PAYLOAD: vault kv put <secrets engine>/<location> @<name of file>.json"
vault kv put labsecrets/labinfo @./vault/files/data.json
green "#--- CLI: Insert some additional secrets for use later in demo / hide action"
vault kv put labsecrets/lab_keypad code="12345" >/dev/null
vault kv put labsecrets/lab_room room="A113" >/dev/null
green "#--- API: WRITE A SECRET"
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    -X POST \
    -d '{"data":{"gmapapikey": "where-am-i-??????"}}' \
    $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq
p "Press Enter to continue"

#-------------------------------------------------------------------------------

# tput clear
cyan "#-------------------------------------------------------------------------------
# 4_enable_db.sh - ENABLE DYNAMIC SECRETS - DB
#-------------------------------------------------------------------------------\n"
osascript -e "tell application \"pgAdmin 4\" to activate"
set +e
green "#--- Enable Database Secret engine."
vault secrets enable -path=${DB_PATH} database
set -e
green "#--- Configure plugin and connection info that Vault uses to connect to database."
vault write ${DB_PATH}/config/${PGDATABASE} \
    plugin_name=postgresql-database-plugin \
    allowed_roles=* \
    connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:${PGPORT}/${PGDATABASE}?sslmode=disable" \
    username="${VAULT_ADMIN_USER}" \
    password="${VAULT_ADMIN_PW}"

green "Rotate the credentials for ${VAULT_ADMIN_USER} so no human has access to them anymore"
white "vault write -force ${DB_PATH}/rotate-root/${PGDATABASE}"

green "#--- Configure the Vault/Postgres database roles with time bound credential templates"
MAX_TTL=24h

green "#--- Full read can be used by security teams to scan for credentials in any schema - 30s \n"
ROLE_NAME="full-read"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
  GRANT USAGE ON SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\"; 
  GRANT SELECT ON ALL TABLES IN SCHEMA public,it,hr,security,finance,engineering TO \"{{name}}\";"
TTL=30s
write_db_role

green "#--- Full read can be used by security teams to scan for credentials in any schema - 1h \n"
TTL=1h
write_db_role

green "#--- HR will be granted full access to their schema - 30s \n"
ROLE_NAME="hr-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; 
GRANT USAGE ON SCHEMA hr TO \"{{name}}\"; 
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr TO \"{{name}}\";"
TTL=30s
write_db_role

green "#--- HR will be granted full access to their schema - 1h \n"
TTL=1h
write_db_role

green "#--- Engineering will be granted full access to their schema - 30s \n"
green "Engineering will be granted full access to their schema"
ROLE_NAME="engineering-full"
CREATION_STATEMENT="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; 
GRANT USAGE ON SCHEMA engineering TO \"{{name}}\"; 
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA engineering TO \"{{name}}\";"
TTL=30s
write_db_role

green "#--- Engineering will be granted full access to their schema - 1h \n"
TTL=1h
write_db_role
p "Press Enter to continue"

#-------------------------------------------------------------------------------

# tput clear
cyan "#-------------------------------------------------------------------------------
# 5_enable_transit.sh - ENABLE TRANSIT SECRETS
#-------------------------------------------------------------------------------\n"
green "#--- Enable Transit Secret Engine"
set +e
vault secrets enable -path=${TRANSIT_PATH} transit
set -e
green "#--- Create a transit encryption key by the HR team to encrypt/decrypt data.\n"
vault write -f ${TRANSIT_PATH}/keys/hr

#-------------------------------------------------------------------------------

tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE AND CONFIGURE THE LDAP AUTH METHOD
#-------------------------------------------------------------------------------\n"

green "#--- Enable ldap auth method for two paths."
set +e
vault auth enable -path=ldap-um ldap
vault auth enable -path=ldap-mo ldap
set -e

green "Configure connection details for your LDAP server, 
information on how to authenticate users, 
and instructions on how to query for group membership. 
The configuration options are categorized and detailed below."

green "Configure Unique Member group lookups"
# Using group of unique names lookups
export LDAP_URL="ldap://127.0.0.1"
echo vault write auth/ldap-um/config \
    url="${LDAP_URL}" \
    binddn="${BIND_DN}" \
    bindpass="${BIND_PW}" \
    userdn="${USER_DN}" \
    userattr="${USER_ATTR}" \
    groupdn="${GROUP_DN}" \
    groupfilter="${UM_GROUP_FILTER}" \
    groupattr="${UM_GROUP_ATTR}" \
    insecure_tls=true

vault write auth/ldap-um/config \
    url="${LDAP_URL}" \
    binddn="${BIND_DN}" \
    bindpass="${BIND_PW}" \
    userdn="${USER_DN}" \
    userattr="${USER_ATTR}" \
    groupdn="${GROUP_DN}" \
    groupfilter="${UM_GROUP_FILTER}" \
    groupattr="${UM_GROUP_ATTR}" \
    insecure_tls=true

p

green "Configure MemberOf group lookups"

echo vault write auth/ldap-mo/config \
    url="${LDAP_URL}" \
    binddn="${BIND_DN}" \
    bindpass="${BIND_PW}" \
    userdn="${USER_DN}" \
    userattr="${USER_ATTR}" \
    groupdn="${USER_DN}" \
    groupfilter="${MO_GROUP_FILTER}" \
    groupattr="${MO_GROUP_ATTR}" \
    insecure_tls=true

vault write auth/ldap-mo/config \
    url="${LDAP_URL}" \
    binddn="${BIND_DN}" \
    bindpass="${BIND_PW}" \
    userdn="${USER_DN}" \
    userattr="${USER_ATTR}" \
    groupdn="${USER_DN}" \
    groupfilter="${MO_GROUP_FILTER}" \
    groupattr="${MO_GROUP_ATTR}" \
    insecure_tls=true

p

#-------------------------------------------------------------------------------

tput clear
cyan "#-------------------------------------------------------------------------------
# GENERATE DYNAMIC POLICY
#-------------------------------------------------------------------------------\n"
UM_ACCESS=$(vault auth list -format=json | jq -r '.["ldap-um/"].accessor')
MO_ACCESS=$(vault auth list -format=json | jq -r '.["ldap-mo/"].accessor')

# green "Generating a dynamic policy under policies/kv-user-template-policy.hcl.  
# This needs to be done because the ACL templates need to know the local LDAP auth method accessors"
mkdir -p ./tmp
tee ./tmp/kv-user-template-policy.hcl << EOF
# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["list", "read", "delete"]
}

# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["list", "read", "delete"]
}
EOF

vault policy write kv-user-template ./tmp/kv-user-template-policy.hcl

p

#-------------------------------------------------------------------------------

# tput clear
cyan "#-------------------------------------------------------------------------------
# Running: CREATE POLICIES
#-------------------------------------------------------------------------------\n"
green "Load the policy into Vault\n"
vault policy write base ./vault/files/base.hcl

p "Press Enter to continue"


cyan "# KV Policies"
green "Create KV policy for IT access"
vault policy write kv-it ./vault/policies/kv-it-policy.hcl

cyan "# DB Policies"
green "Create DB policies for access."
cat ./vault/policies/db-full-read-policy.hcl
vault policy write db-full-read ./vault/policies/db-full-read-policy.hcl
cat ./vault/policies/db-engineering-policy.hcl
vault policy write db-engineering ./vault/policies/db-engineering-policy.hcl
cat ./vault/policies/db-hr-policy.hcl
vault policy write db-hr ./vault/policies/db-hr-policy.hcl

# Transit Policies
green 'Create DB transit policies for HR.'
cat ./vault/policies/transit-hr-policy.hcl
vault policy write transit-hr ./vault/policies/transit-hr-policy.hcl

#-------------------------------------------------------------------------------

# tput clear
cyan "#-------------------------------------------------------------------------------
#--- Running: Associating Policies with Authentication Methods
#-------------------------------------------------------------------------------\n"
# Unique Member configs
green "Setup Unique Member group logins for LDAP.   These can use alias names when logging in"
echo
vault write auth/ldap-um/groups/it policies=kv-it,kv-user-template
vault write auth/ldap-um/groups/security policies=db-full-read,kv-user-template

# MemberOf configs
green "Setup MemberOf group logins for LDAP.   Need to use the entire DN for the group here as these are in the user's attributes"
echo
#pe "vault write auth/ldap-mo/groups/cn=hr,ou=um_group,dc=ourcorp,dc=com policies=db-hr,transit-hr,kv-user-template"
#pe "vault write auth/ldap-mo/groups/cn=engineering,ou=um_group,dc=ourcorp,dc=com policies=db-engineering,kv-user-template"
vault write auth/ldap-mo/groups/hr policies=db-hr,transit-hr,kv-user-template
vault write auth/ldap-mo/groups/engineering policies=db-engineering,kv-user-template

#-------------------------------------------------------------------------------

tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE USER PASSWORD AUTHENTICATION
#-------------------------------------------------------------------------------\n"

green "#--- Enable the userpass method."
set +e
vault auth enable userpass
set -e

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE USERS TO INTERACT WITH VAULT
#-------------------------------------------------------------------------------\n"
green "Create users that can consume Vault and assign a role to define authorization."
vault write auth/userpass/users/beaker password="meep" policies="default"
vault write auth/userpass/users/bunsen password="honeydew" policies="base"

green "Create IT user (deepak) with policies:kv-it,kv-user-template"
vault write auth/userpass/users/deepak password=thispasswordsucks policies=kv-it,kv-user-template

green "Create Engineering user (chun) with policies: kv-user-template"
vault write auth/userpass/users/chun password=thispasswordsucks policies=kv-user-template


tput clear
cyan "#-------------------------------------------------------------------------------
# Step: Create an Entity
#-------------------------------------------------------------------------------\n"

green "In the output, locate the Accessor value for userpass:"
vault auth list -format=json | jq -r '."userpass/".accessor' | tee /tmp/userpass_accessor.txt

vault write -format=json identity/entity name="engineer-chun" policies="kv-user-template" \
    metadata=organization="ACME Inc." metadata=team="QA" \
    | jq -r ".data.id" | tee /tmp/entity_id.txt

cyan "#-------------------------------------------------------------------------------
# Step: Create an Entity Alias
#-------------------------------------------------------------------------------\n"
vault write identity/entity-alias name="chun" \
    canonical_id=$(cat /tmp/entity_id.txt) \
    mount_accessor=$(cat /tmp/userpass_accessor.txt)

#-------------------------------------------------------------------------------










tput clear
echo "#-------------------------------------------------------------------------------
# SENTINEL
#-------------------------------------------------------------------------------\n"

cyan "
# CREATE AN EGP POLICY NAMED: cidr-check.
#-------------------------------------------------------------------------------\n"
green "Create/get sentinel policy"
# wget -P ./vault/files https://raw.githubusercontent.com/hashicorp/vault-guides/master/governance/validation-policies/cidr-check.sentinel
tee ./vault/files/cidr-check.sentinel <<EOF
# dynamically generated by script: $0
import "sockaddr"
import "strings"

# Only care about create, update, and delete operations against secret path
#--- Uncomment if you want to add precond
precond = rule {
    request.operation in ["create", "update", "delete"] and
    strings.has_prefix(request.path, "labsecrets/")
}

# Requests to come only from our private IP range
cidrcheck = rule {
    sockaddr.is_contained(request.connection.remote_addr, "122.22.3.4/32")
}

# Check the precondition before execute the cidrcheck
main = rule {
    cidrcheck
}
# #--- Uncomment if you want to add precond
# main = rule when precond {
#     cidrcheck
# }
EOF

green "#--- Store the Base64 encoded cidr-check.sentinel policy in an environment 
variable named POLICY."
POLICY=$(base64 ./vault/files/cidr-check.sentinel)

green "#--- Create a policy cidr-check with enforcement level of hard-mandatory to 
reject all requests coming from IP addressed that are not internal."
vault write sys/policies/egp/cidr-check \
    policy="${POLICY}" \
    paths="labsecrets/*" \
    enforcement_level="hard-mandatory"


cyan "
# CREATE AN EGP POLICY NAMED: business-hrs.
#-------------------------------------------------------------------------------\n"

green "#--- Create sentinel policy for business-hrs"
tee ./vault/files/business-hrs.sentinel <<EOF
# dynamically generated by script: $0
import "time"

# We expect requests to only happen during work days (0 for Sunday, 6 for Saturday)
workdays = rule {
    time.now.weekday > 0 and time.now.weekday < 6 
}

# We expect requests to only happen during work hours
workhours = rule {
    time.now.hour > 7 and time.now.hour < 18 
}

main = rule {
    workdays and workhours
}
EOF

green "#--- Encode the business-hrs policy"
POLICY2=$(base64 ./vault/files/business-hrs.sentinel)

green "#--- Create a policy with soft-mandatory enforcement-level"
vault write sys/policies/egp/business-hrs \
    policy="${POLICY2}" \
    paths="labsecrets/labaccounting/*" \
    enforcement_level="soft-mandatory"


cyan "
# CREATE AN EGP POLICY NAMED: validate-aws-keys
#-------------------------------------------------------------------------------\n"

wget -P ./vault/files https://raw.githubusercontent.com/hashicorp/vault-guides/master/governance/validation-policies/validate-aws-keys.sentinel
green "#--- Encode the validate-aws-keys policy"
POLICY3=$(base64 ./vault/files/validate-aws-keys.sentinel)

green "#--- Create a policy with soft-mandatory enforcement-level"
vault write sys/policies/egp/validate-aws-keys \
    policy="${POLICY3}" \
    paths="*" \
    enforcement_level="soft-mandatory"





























