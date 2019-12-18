. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}

tput clear
cyan "#-------------------------------------------------------------------------------
#--- Running: $0: Associating Policies with Authentication Methods
#-------------------------------------------------------------------------------\n"
# Unique Member configs
green "Setup Unique Member group logins for LDAP.   These can use alias names when logging in"
echo
pe "vault write auth/ldap-um/groups/it policies=kv-it,kv-user-template"
pe "vault write auth/ldap-um/groups/security policies=db-full-read,kv-user-template"
# Following two lines are tests by pp.
# pe "vault write auth/ldap-um/groups/hr policies=db-hr,transit-hr,kv-user-template"
# pe "vault write auth/ldap-um/groups/engineering policies=db-engineering,kv-user-template"

# MemberOf configs
green "Setup MemberOf group logins for LDAP.   Need to use the entire DN for the group here as these are in the user's attributes"
echo
#pe "vault write auth/ldap-mo/groups/cn=hr,ou=um_group,dc=ourcorp,dc=com policies=db-hr,transit-hr,kv-user-template"
#pe "vault write auth/ldap-mo/groups/cn=engineering,ou=um_group,dc=ourcorp,dc=com policies=db-engineering,kv-user-template"
pe "vault write auth/ldap-mo/groups/hr policies=db-hr,transit-hr,kv-user-template"
pe "vault write auth/ldap-mo/groups/engineering policies=db-engineering,kv-user-template"




