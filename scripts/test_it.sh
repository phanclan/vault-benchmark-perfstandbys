. env.sh

tput clear
cyan "#------------------------------------------------------------------------------
#--- Running: $0: Testing IT requirements
#------------------------------------------------------------------------------\n"
echo
green "Unset VAULT_TOKEN so we don't accidentally carry over the root token"
pe "unset VAULT_TOKEN"

green "Login to Vault with IT member."
# export VAULT_ADDR=http://127.0.0.1:8207
pe "vault login -method=ldap -path=ldap-um username=deepak password=${USER_PASSWORD} | tee /tmp/deepak.txt"
# pe "vault login -method=userpass username=deepak password=thispasswordsucks"
# export VAULT_TOKEN=$(cat /tmp/deepak.txt | awk '/---/ {getline; print $NF}')
p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
#--- POSITIVE TESTS
#------------------------------------------------------------------------------\n"
echo
green "Test KV puts to allowed paths"
pe "vault kv put kv-blog/it/servers/hr/root password=rootntootn"
pe "vault kv put kv-blog/it/routers/snmp/read-write password=snortymcsnortyton"

green "#--- Access to kv-blog/<user_name>/email is allowed via an ACL templated path!"
pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"
yellow 'NOTE: deepak matched this path "kv-blog/data/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"'
p "Press Enter to continue"

tput clear
green "#--- Test KV gets to allowed paths"
pe "vault kv get kv-blog/it/servers/hr/root"
pe "vault kv get kv-blog/it/routers/snmp/read-write"
pe "vault kv get kv-blog/deepak/email"
p "Press Enter to continue"

tput clear
red "#------------------------------------------------------------------------------
#--- NEGATIVE TESTS - EXPECT FAILURES
#------------------------------------------------------------------------------\n"
echo

green "Test KV gets to disallowed paths"
pe "vault kv get kv-blog/hr/servers/hr/root" 
pe "vault kv get kv-blog/hr/routers/snmp/read-write"

yellow "Test KV puts to disallowed paths"
pe "vault kv put kv-blog/hr/servers/hr/root password=rootntootn"
pe "vault kv put kv-blog/hr/routers/snmp/read-write password=snortymcsnortyton"

yellow "Check against another user's path controlled by ACL templating"
pe "vault kv put kv-blog/alice/email password=doesntlooklikeanythingtome"

yellow "Test access to database endpoints"
pe "vault read db-blog/creds/mother-full-read-1m"
