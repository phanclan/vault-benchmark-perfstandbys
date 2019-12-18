. env.sh
echo
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
export VAULT_PORT=${VAULT_PORT:-10101}
export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}
export LDAP_HOST=openldap

cyan "Running: $0: Enable and Configure the LDAP Auth Method"
echo

green "Enable ldap auth method for two paths."
pe "vault auth enable -path=ldap-um ldap"
pe "vault auth enable -path=ldap-mo ldap"

green "Configure connection details for your LDAP server, 
information on how to authenticate users, 
and instructions on how to query for group membership. 
The configuration options are categorized and detailed below."
green "Configure Unique Member group lookups"
# Using group of unique names lookups
cat << EOF
vault write auth/ldap-um/config
    url="${LDAP_URL}"
    binddn="${BIND_DN}"
    bindpass="${BIND_PW}"
    userdn="${USER_DN}"
    userattr="${USER_ATTR}"
    groupdn="${GROUP_DN}"
    groupfilter="${UM_GROUP_FILTER}"
    groupattr="${UM_GROUP_ATTR}"
    insecure_tls=true
EOF
p

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

echo
green "Configure MemberOf group lookups"
cat << EOF
vault write auth/ldap-mo/config
    url="${LDAP_URL}"
    binddn="${BIND_DN}"
    bindpass="${BIND_PW}"
    userdn="${USER_DN}"
    userattr="${USER_ATTR}"
    groupdn="${USER_DN}"
    groupfilter="${MO_GROUP_FILTER}"
    groupattr="${MO_GROUP_ATTR}"
    insecure_tls=true
EOF
p

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
